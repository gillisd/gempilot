# JRuby-safe dev gems + betterleaks integration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make gempilot's own bundle install on JRuby, and add betterleaks secret-scanning (git hook + rake task + CI) to generated gems, to gempilot itself, and as a retrofit command for existing gems.

**Architecture:** Two independent changes. (A) Wrap native-extension dev gems in `platforms :mri` in gempilot's Gemfile. (B) Ship a `Gempilot::BetterleaksTask` rake task-lib and static hook/CI templates, wired in three ways: `create --[no-]betterleaks` (new gems), a new `gempilot setup betterleaks` command (existing gems), and gempilot's own repo (dogfood). A shared `BetterleaksInstaller` mixin is the single source of truth for the file operations.

**Tech Stack:** Ruby, CommandKit, Rake::TaskLib, ERB templates, minitest + rspec, rubocop (double-quote style, `rubocop-claude` plugin).

**Spec:** `docs/superpowers/specs/2026-07-26-betterleaks-and-jruby-design.md`

> **Note:** the Task 2/3/4 lib snippets below were written to their real paths and verified `rubocop`-clean + `rake zeitwerk:validate`-clean against this repo before this plan was finalized, then reverted. Reproduce them exactly.

---

## Conventions for every task

- **Strings:** double quotes. **No** `# frozen_string_literal` comment. Trailing commas in multiline literals/args. **No non-ASCII** in code/comments (`Claude/NoFancyUnicode` — no em dashes).
- **Docs:** every public class/module gets a `##` rdoc block immediately above it (no blank line between).
- **Metrics:** methods ≤10 lines, ABC ≤17, non-test blocks ≤8 lines. `test/**` is exempt from `Metrics/{Method,Class,Abc}Length`; `spec/**` is exempt only from `Metrics/BlockLength`.
- **`super` vs `super()`:** call bare `super` when a method takes no args (`Style/SuperArguments`); use `super()` only to pass *no* args from a method that *does* take args (as `version_task.rb` does for its `root:` param).
- **Run one minitest file:** `bundle exec ruby -Itest -Ilib <path>` (filter with `-n "/regex/"`)
- **Run one spec file:** `bundle exec rspec <path>`
- **Full suite:** `bundle exec rake test && bundle exec rake spec && bundle exec rake rubocop`
- `data/templates/**` is excluded from rubocop, so hook/YAML/ERB template files there need not be rubocop-clean.

---

## Task 1: Issue A — make native dev gems MRI-only

**Files:**
- Modify: `/workspace/Gemfile`

- [ ] **Step 1: Edit the Gemfile**

Remove the standalone `gem "debug", "~> 1.10"`, `gem "rbs"`, and `gem "repl_type_completor"` lines and add a platform block at the end. The file must read exactly:

```ruby
source "https://rubygems.org"

gemspec

gem "benchmark"
gem "irb", "~> 1.15"
gem "minitest"
gem "minitest-reporters"
gem "observer"
gem "rake", require: false
gem "rdoc"
gem "rspec"
gem "rubocop"
gem "rubocop-claude"
gem "rubocop-minitest"
gem "rubocop-performance"
gem "rubocop-rake"
gem "rubocop-rspec", "~> 3.9"
gem "zeitwerk"

# rbs, repl_type_completor, and debug ship native extensions that fail to
# build on JRuby; scope them to MRI so `bundle install` works there too.
platforms :mri do
  gem "debug", "~> 1.10"
  gem "rbs"
  gem "repl_type_completor"
end
```

- [ ] **Step 2: Verify the bundle still resolves on MRI**

Run: `bundle install`
Expected: completes without error. `git diff Gemfile.lock` should show no change to the resolved dependency set on this (MRI) platform; a churned `BUNDLED WITH` or platform line is harmless — do not treat a trivial lock diff as a failure. (`:mri` also excludes TruffleRuby, which is intended and matches the spec.)

- [ ] **Step 3: Verify rubocop is clean**

Run: `bundle exec rubocop Gemfile`
Expected: `no offenses detected` (top-level list stays alphabetical; the `platforms` block is internally alphabetical: debug < rbs < repl_type_completor).

- [ ] **Step 4: Commit**

```bash
git add Gemfile
git commit -m "Scope rbs, repl_type_completor, and debug to MRI (JRuby bundle fix)"
```

---

## Task 2: betterleaks assets — hook template, CI template, and rake task-lib

Creates the three reusable pieces the rest of the feature depends on. TDD applies to the rake task-lib (it has a spec); the two template files are static and are exercised by Tasks 3 and 4.

**Files:**
- Create: `data/templates/gem/githooks/pre-commit`
- Create: `data/templates/gem/dotfiles/github/workflows/secrets.yml`
- Create: `lib/gempilot/betterleaks_task.rb`
- Test: `spec/gempilot/betterleaks_task_spec.rb`

- [ ] **Step 1: Create the pre-commit hook template**

`data/templates/gem/githooks/pre-commit`:

```bash
#!/usr/bin/env bash
set -euo pipefail

if ! command -v betterleaks >/dev/null 2>&1; then
  echo "betterleaks not found on PATH; skipping secret scan." >&2
  echo "Install it (e.g. 'brew install betterleaks') to scan staged changes." >&2
  exit 0
fi

exec betterleaks git --pre-commit --redact --staged --verbose
```

- [ ] **Step 2: Create the CI workflow template**

`data/templates/gem/dotfiles/github/workflows/secrets.yml`:

```yaml
name: Secret Scan

on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]

permissions:
  contents: read

jobs:
  betterleaks:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 0
    - name: Set up Go
      uses: actions/setup-go@v5
      with:
        go-version: stable
    - name: Install betterleaks
      run: go install github.com/betterleaks/betterleaks@latest
    - name: Scan for secrets
      run: betterleaks git --redact --verbose
```

- [ ] **Step 3: Write the failing spec for the rake task-lib**

`spec/gempilot/betterleaks_task_spec.rb`:

```ruby
require "spec_helper"

RSpec.describe Gempilot::BetterleaksTask do
  around do |example|
    old_app = Rake.application
    Rake.application = Rake::Application.new
    example.run
  ensure
    Rake.application = old_app
  end

  before { described_class.new }

  it "defines the betterleaks task" do
    expect(Rake::Task).to be_task_defined("betterleaks")
  end

  context "when betterleaks is not installed" do
    around do |example|
      original = ENV.fetch("PATH", nil)
      Dir.mktmpdir("empty_path") do |dir|
        ENV["PATH"] = dir
        example.run
      end
    ensure
      ENV["PATH"] = original
    end

    it "skips the scan without raising" do
      expect { Rake::Task["betterleaks"].invoke }.not_to raise_error
    end
  end
end
```

- [ ] **Step 4: Run the spec to verify it fails**

Run: `bundle exec rspec spec/gempilot/betterleaks_task_spec.rb`
Expected: FAIL — `uninitialized constant Gempilot::BetterleaksTask`.

- [ ] **Step 5: Implement the rake task-lib**

`lib/gempilot/betterleaks_task.rb` (note bare `super`, and `ENV.fetch` — both required by rubocop):

```ruby
require "rake/tasklib"
require_relative "../gempilot"

module Gempilot
  ## Rake task that scans the repository for committed secrets using
  ## betterleaks (https://github.com/betterleaks/betterleaks).
  ##
  ## Owned by gempilot and consumed by generated gems via
  ## <tt>require "gempilot/betterleaks_task"; Gempilot::BetterleaksTask.new</tt>.
  ## betterleaks is a standalone binary, not a gem, so the task degrades
  ## gracefully: when betterleaks is absent from +PATH+ it prints an install
  ## hint and succeeds instead of failing, keeping the task usable on machines
  ## and Ruby engines where the scanner is unavailable.
  class BetterleaksTask < Rake::TaskLib
    def initialize
      super
      define_scan_task
    end

    private

    def define_scan_task
      desc "Scan the repository for committed secrets with betterleaks"
      task(:betterleaks) { scan }
    end

    def scan
      return warn_missing unless betterleaks_available?

      sh "betterleaks", "git", "--redact", "--verbose"
    end

    def betterleaks_available?
      ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |dir|
        File.executable?(File.join(dir, "betterleaks"))
      end
    end

    def warn_missing
      warn "betterleaks not found on PATH; skipping secret scan " \
           "(install: brew install betterleaks)"
    end
  end
end
```

- [ ] **Step 6: Run the spec to verify it passes**

Run: `bundle exec rspec spec/gempilot/betterleaks_task_spec.rb`
Expected: PASS (2 examples). (Invoking the task prints the "not found" notice to stderr — expected noise, not a failure.)

- [ ] **Step 7: Verify rubocop and Zeitwerk**

Run: `bundle exec rubocop lib/gempilot/betterleaks_task.rb spec/gempilot/betterleaks_task_spec.rb`
Expected: `no offenses detected`.
Run: `bundle exec rake zeitwerk:validate`
Expected: `Zeitwerk: All files loaded successfully.`

- [ ] **Step 8: Commit**

```bash
git add data/templates/gem/githooks/pre-commit data/templates/gem/dotfiles/github/workflows/secrets.yml lib/gempilot/betterleaks_task.rb spec/gempilot/betterleaks_task_spec.rb
git commit -m "Add betterleaks hook/CI templates and Gempilot::BetterleaksTask"
```

---

## Task 3: BetterleaksInstaller mixin + `gempilot setup betterleaks` command

The installer centralizes the file operations; the `Setup` command retrofits an existing gem and is the primary test of the installer (it exercises every installer method under root `.`; Task 4 exercises the copy path under root `@gem_name`).

**Files:**
- Create: `lib/gempilot/cli/betterleaks_installer.rb`
- Create: `lib/gempilot/cli/commands/setup.rb`
- Test: `test/gempilot/cli/setup_command_test.rb`

- [ ] **Step 1: Write the failing test**

`test/gempilot/cli/setup_command_test.rb`:

```ruby
require "test_helper"
require "tmpdir"
require "stringio"

module Gempilot
  class CLI
    class SetupCommandTest < Minitest::Test
      def setup
        @tmpdir = Dir.mktmpdir("setup_command_test")
        @original_dir = Dir.pwd
        Dir.chdir(@tmpdir)
        FileUtils.mkdir_p("lib/my_gem")
        FileUtils.mkdir_p("bin")
        File.write("my_gem.gemspec", 'Gem::Specification.new { |s| s.name = "my_gem" }')
        File.write("Rakefile", %(require "bundler/gem_tasks"\n))
        File.write("bin/setup", "#!/usr/bin/env bash\nbundle install\n")
      end

      def teardown
        Dir.chdir(@original_dir)
        FileUtils.rm_rf(@tmpdir)
      end

      def test_setup_betterleaks_creates_executable_hook
        run_setup_command("betterleaks")

        assert_path_exists ".githooks/pre-commit"
        assert_predicate Pathname(".githooks/pre-commit"), :executable?
        assert_includes File.read(".githooks/pre-commit"), "betterleaks git --pre-commit"
      end

      def test_setup_betterleaks_creates_ci_workflow
        run_setup_command("betterleaks")

        assert_path_exists ".github/workflows/secrets.yml"
        assert_includes File.read(".github/workflows/secrets.yml"), "betterleaks"
      end

      def test_setup_betterleaks_wires_rakefile
        run_setup_command("betterleaks")

        rakefile = File.read("Rakefile")

        assert_includes rakefile, 'require "gempilot/betterleaks_task"'
        assert_includes rakefile, "Gempilot::BetterleaksTask.new"
      end

      def test_setup_betterleaks_wires_bin_setup
        run_setup_command("betterleaks")

        assert_includes File.read("bin/setup"), "git config core.hooksPath .githooks"
      end

      def test_setup_betterleaks_is_idempotent
        run_setup_command("betterleaks")

        stdout = StringIO.new
        command = Commands::Setup.new(stdout: stdout)
        command.define_singleton_method(:sh) { |*_args| nil }
        exit_code = command.main(["betterleaks"])

        rakefile = File.read("Rakefile")

        assert_equal 0, exit_code
        assert_equal 1, rakefile.scan("Gempilot::BetterleaksTask.new").size
        assert_equal 1, File.read("bin/setup").scan("core.hooksPath").size
        assert_includes stdout.string, "skip"
      end

      def test_setup_fails_without_gemspec
        FileUtils.rm("my_gem.gemspec")
        stdout = StringIO.new
        command = Commands::Setup.new(stdout: stdout)
        command.define_singleton_method(:sh) { |*_args| nil }

        assert_equal 1, command.main(["betterleaks"])
      end

      def test_setup_fails_with_unknown_feature
        stdout = StringIO.new
        command = Commands::Setup.new(stdout: stdout)
        command.define_singleton_method(:sh) { |*_args| nil }

        assert_equal 1, command.main(["widget"])
      end

      private

      def run_setup_command(*args)
        stdout = StringIO.new
        command = Commands::Setup.new(stdout: stdout)
        # Stub sh so `git config core.hooksPath` is not run against the non-repo tmpdir.
        command.define_singleton_method(:sh) { |*_args| nil }
        command.main(args)
      end
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bundle exec ruby -Itest -Ilib test/gempilot/cli/setup_command_test.rb`
Expected: FAIL — `uninitialized constant Gempilot::CLI::Commands::Setup`.

- [ ] **Step 3: Implement the installer mixin**

`lib/gempilot/cli/betterleaks_installer.rb`:

```ruby
module Gempilot
  class CLI
    ## Installs the betterleaks secret-scanning integration into a gem: a
    ## tracked +.githooks/pre-commit+ hook, a +secrets.yml+ CI workflow, and
    ## Rakefile / +bin/setup+ wiring.
    ##
    ## Shared by the +create+ command (fresh scaffold) and the
    ## +setup betterleaks+ command (retrofit into an existing gem). Every
    ## operation is idempotent, so the retrofit command can run repeatedly
    ## without duplicating files or lines.
    ##
    ## Expects the including class to provide Generator methods (+cp+,
    ## +chmod+, +mkdir+, +create_file+, +print_action+) and +colors+.
    module BetterleaksInstaller
      HOOKS_PATH = ".githooks".freeze
      HOOK_DEST = ".githooks/pre-commit".freeze
      WORKFLOW_DEST = ".github/workflows/secrets.yml".freeze
      HOOK_SOURCE = "githooks/pre-commit".freeze
      WORKFLOW_SOURCE = "dotfiles/github/workflows/secrets.yml".freeze
      RAKE_LINES = <<~RUBY.freeze
        require "gempilot/betterleaks_task"
        Gempilot::BetterleaksTask.new
      RUBY
      SETUP_LINE = "git config core.hooksPath #{HOOKS_PATH}".freeze
      DEFAULT_SETUP = <<~BASH.freeze
        #!/usr/bin/env bash
        set -euo pipefail

        bundle install
      BASH

      private

      def install_betterleaks_files(root: ".")
        copy_hook(root)
        copy_workflow(root)
      end

      def copy_hook(root)
        dest = File.join(root, HOOK_DEST)
        return print_skip(dest) if File.exist?(dest)

        mkdir(File.dirname(dest))
        cp HOOK_SOURCE, dest
        chmod "+x", dest
      end

      def copy_workflow(root)
        dest = File.join(root, WORKFLOW_DEST)
        return print_skip(dest) if File.exist?(dest)

        mkdir(File.dirname(dest))
        cp WORKFLOW_SOURCE, dest
      end

      def wire_rakefile(root: ".")
        append_once(File.join(root, "Rakefile"), RAKE_LINES)
      end

      def wire_setup_script(root: ".")
        path = File.join(root, "bin", "setup")
        ensure_setup_script(path)
        append_once(path, SETUP_LINE)
      end

      def ensure_setup_script(path)
        return if File.exist?(path)

        mkdir(File.dirname(path))
        create_file(path, DEFAULT_SETUP)
        chmod "+x", path
      end

      def append_once(path, snippet)
        body = File.exist?(path) ? File.read(path) : ""
        return print_skip(path) if body.include?(snippet.strip)

        write_appended(path, body, snippet)
        print_action "update", path
      end

      def write_appended(path, body, snippet)
        prefix = body.empty? ? "" : "#{body.chomp}\n\n"
        File.write(path, "#{prefix}#{snippet.chomp}\n")
      end

      def print_skip(path)
        puts "\t#{colors.bold(colors.yellow("skip"))}\t#{colors.yellow(path)}"
      end
    end
  end
end
```

- [ ] **Step 4: Implement the Setup command**

`lib/gempilot/cli/commands/setup.rb` (keep the doc comment ASCII — no em dash):

```ruby
module Gempilot
  class CLI
    module Commands
      ## Sets up an optional tooling integration inside an existing gem.
      ##
      ## Currently supports betterleaks secret scanning:
      ## <tt>gempilot setup betterleaks</tt> installs the pre-commit hook, CI
      ## workflow, and rake task wiring. Idempotent, safe to re-run.
      class Setup < Command
        include Generator
        include GemContext
        include BetterleaksInstaller

        template_dir File.join(Gempilot::ROOT, "data", "templates", "gem")

        usage "[options] FEATURE"
        description "Set up a tooling integration in an existing gem"

        examples [
          "betterleaks",
        ]

        FEATURES = %w[betterleaks].freeze

        argument :feature, required: false,
                           desc: "Integration to set up (betterleaks)"

        def run(feature = nil)
          feature ||= prompt_for_feature
          detect_gem_context
          dispatch_setup(feature)
        end

        private

        def prompt_for_feature
          puts colors.bright_black("Which integration do you want to set up?")
          ask_multiple_choice(colors.green("Feature"), FEATURES)
        end

        def dispatch_setup(feature)
          case feature
          when "betterleaks" then setup_betterleaks
          else
            puts colors.red("Unknown feature '#{feature}'. Available: #{FEATURES.join(", ")}.")
            exit 1
          end
        end

        def setup_betterleaks
          print_setup_banner("betterleaks")
          install_betterleaks_files
          wire_rakefile
          wire_setup_script
          activate_hooks_path
        end

        def activate_hooks_path
          sh "git", "config", "core.hooksPath", HOOKS_PATH
        end

        def print_setup_banner(feature)
          puts
          puts colors.bright_white("Setting up ") + colors.bold(colors.cyan(feature)) + colors.bright_white("...")
          puts
        end
      end
    end
  end
end
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bundle exec ruby -Itest -Ilib test/gempilot/cli/setup_command_test.rb`
Expected: PASS (7 tests).

- [ ] **Step 6: Verify the command is wired and rubocop is clean**

Run: `bundle exec exe/gempilot help setup`
Expected: prints usage `gempilot setup [options] FEATURE` with the description.
Run: `bundle exec rubocop lib/gempilot/cli/betterleaks_installer.rb lib/gempilot/cli/commands/setup.rb`
Expected: `no offenses detected`.
Run: `bundle exec rake zeitwerk:validate`
Expected: `Zeitwerk: All files loaded successfully.`

- [ ] **Step 7: Commit**

```bash
git add lib/gempilot/cli/betterleaks_installer.rb lib/gempilot/cli/commands/setup.rb test/gempilot/cli/setup_command_test.rb
git commit -m "Add 'gempilot setup betterleaks' retrofit command and installer"
```

---

## Task 4: Wire betterleaks into `gempilot create`

Adds the default-on `--[no-]betterleaks` option, renders the artifacts for new gems, and updates every non-interactive create invocation in both suites so the new prompt never blocks on stdin.

**IMPORTANT ordering:** Step 1 updates the shared `run_create_command` helper too, because `test_no_betterleaks_flag_omits_integration` matches the `-n "/betterleaks/"` filter and must not hit the prompt in Step 6. All *other* call sites are updated in Step 7 (they only run in the full suite at Step 8).

**Files:**
- Modify: `lib/gempilot/cli/commands/create.rb`
- Modify: `lib/gempilot/cli/gem_builder.rb`
- Modify: `data/templates/gem/Rakefile.erb`
- Modify: `data/templates/gem/bin/setup.erb`
- Test: `test/gempilot/cli/create_command_test.rb` (+ 6 spec files, listed in Step 7)

- [ ] **Step 1: Write the failing betterleaks create tests + update the shared helper**

In `test/gempilot/cli/create_command_test.rb`, (a) add these tests inside `class CreateCommandTest` before the `private` keyword:

```ruby
      # betterleaks integration

      def test_betterleaks_creates_executable_hook
        run_create_with_betterleaks("test_gem")

        assert_path_exists "test_gem/.githooks/pre-commit"
        assert_predicate Pathname("test_gem/.githooks/pre-commit"), :executable?
        assert_includes File.read("test_gem/.githooks/pre-commit"), "betterleaks git --pre-commit"
      end

      def test_betterleaks_creates_secrets_workflow
        run_create_with_betterleaks("test_gem")

        assert_path_exists "test_gem/.github/workflows/secrets.yml"
      end

      def test_betterleaks_wires_rakefile
        run_create_with_betterleaks("test_gem")

        assert_includes File.read("test_gem/Rakefile"), "Gempilot::BetterleaksTask.new"
      end

      def test_betterleaks_wires_bin_setup
        run_create_with_betterleaks("test_gem")

        assert_includes File.read("test_gem/bin/setup"), "git config core.hooksPath .githooks"
      end

      def test_betterleaks_sets_hooks_path_on_git_init
        sh_calls = []
        stdout = StringIO.new
        args = [
          "--author", "Test Author", "--email", "test@example.com",
          "--summary", "A test gem", "--ruby-version", "3.4.8",
          "--test", "minitest", "--no-exe", "--git", "--branch", "master",
          "--betterleaks", "test_gem"
        ]
        command = Commands::Create.new(stdout: stdout)
        command.define_singleton_method(:sh) { |cmd, *arguments| sh_calls << [cmd, *arguments] }
        command.main(args)

        assert_includes sh_calls, ["git", "config", "core.hooksPath", ".githooks"]
      end

      def test_no_betterleaks_flag_omits_integration
        run_create_command("test_gem")

        refute_path_exists "test_gem/.githooks/pre-commit"
        refute_path_exists "test_gem/.github/workflows/secrets.yml"
        refute_includes File.read("test_gem/Rakefile"), "BetterleaksTask"
        refute_includes File.read("test_gem/bin/setup"), "core.hooksPath"
      end
```

(b) In the `private` section, add the betterleaks helper and add `"--no-betterleaks",` to the existing `run_create_command` args array (before `*extra_args`):

```ruby
      def run_create_with_betterleaks(gem_name)
        stdout = StringIO.new
        args = [
          "--author", "Test Author",
          "--email", "test@example.com",
          "--summary", "A test gem",
          "--ruby-version", "3.4.8",
          "--test", "minitest",
          "--no-exe",
          "--no-git",
          "--betterleaks",
          gem_name
        ]
        command = Commands::Create.new(stdout: stdout)
        command.define_singleton_method(:sh) { |_cmd, *_arguments| nil }
        command.main(args)
      end
```

The existing `run_create_command` array becomes:

```ruby
        args = [
          "--author", "Test Author",
          "--email", "test@example.com",
          "--summary", "A test gem",
          "--ruby-version", "3.4.8",
          "--test", "minitest",
          "--no-exe",
          "--no-git",
          "--no-betterleaks",
          *extra_args,
          gem_name
        ]
```

- [ ] **Step 2: Run the new tests to verify they fail**

Run: `bundle exec ruby -Itest -Ilib test/gempilot/cli/create_command_test.rb -n "/betterleaks/"`
Expected: FAIL — `--betterleaks`/`--no-betterleaks` are not defined options yet, so create rejects them and builds nothing. The six presence tests (`test_betterleaks_*`) fail their `assert_*`; `test_no_betterleaks_flag_omits_integration` happens to pass (nothing is generated, so its `refute_*`s hold). This confirms the tests exercise the new option.

- [ ] **Step 3: Add the `--[no-]betterleaks` option and collection to create.rb**

In `lib/gempilot/cli/commands/create.rb`, add `include BetterleaksInstaller` under `include GemBuilder`:

```ruby
        include Generator
        include GemBuilder
        include BetterleaksInstaller
```

Add the option declaration after the `option :exe, ...` line:

```ruby
        option :betterleaks, long: "--[no-]betterleaks",
                             desc: "Set up betterleaks secret scanning"
```

Add the collect call to `collect_build_options` (between exe and git):

```ruby
        def collect_build_options
          collect_test_framework
          collect_exe_option
          collect_betterleaks_option
          collect_git_options
        end
```

Add the collection method (guard form; sets `@betterleaks` in both branches) after `collect_exe_option`:

```ruby
        def collect_betterleaks_option
          return @betterleaks = options[:betterleaks] if options.key?(:betterleaks)

          puts
          puts colors.bright_black("betterleaks scans staged changes for secrets before each commit.")
          @betterleaks = ask_yes_or_no(colors.green("Set up betterleaks"), default: true)
        end
```

- [ ] **Step 4: Render the artifacts (edits span TWO files)**

**4a. In `lib/gempilot/cli/commands/create.rb`** — `scaffold_gem` lives here. Add `render_betterleaks` after `render_executable`:

```ruby
        def scaffold_gem
          create_directories
          render_core_templates
          render_test_templates
          render_dev_files
          render_config_files
          render_executable
          render_betterleaks
          run_bundle_install
          initialize_git_repo
        end
```

**4b. In `lib/gempilot/cli/gem_builder.rb`** — update the module doc comment to mention the new ivar/dependency, add the `render_betterleaks` method (place it after `render_executable`), and add the hook-path activation to `initialize_git_repo`.

Update the module doc comment (`gem_builder.rb:4-8`) to append betterleaks to the expected inputs:

```ruby
    ## Expects the including class to provide Generator methods (+mkdir+, +erb+,
    ## +chmod+, +cp+, +cd+, +sh+), BetterleaksInstaller's +install_betterleaks_files+,
    ## and the following instance variables: +@gem_name+, +@require_path+,
    ## +@module_name+, +@hyphenated+, +@test_framework+, +@branch+, +@betterleaks+.
```

Add the method:

```ruby
      def render_betterleaks
        return unless @betterleaks

        install_betterleaks_files(root: @gem_name)
      end
```

Change `initialize_git_repo` (use the `BetterleaksInstaller::HOOKS_PATH` constant, not a literal):

```ruby
      def initialize_git_repo
        return unless options[:git]

        cd @gem_name do
          sh "git", "init", "-q", "-b", @branch
          sh "git", "config", "core.hooksPath", BetterleaksInstaller::HOOKS_PATH if @betterleaks
          sh "git", "add", "."
          sh "git", "commit", "-q", "-m", commit_message
        end
      end
```

- [ ] **Step 5: Add ERB conditionals to the templates**

In `data/templates/gem/Rakefile.erb`, insert the betterleaks wiring between the ZeitwerkTask block and the default-task block. That section must read:

```erb
require "gempilot/zeitwerk_task"
Gempilot::ZeitwerkTask.new
<% if @betterleaks -%>

require "gempilot/betterleaks_task"
Gempilot::BetterleaksTask.new
<% end -%>

<% if @test_framework == :minitest -%>
task default: [:test, :rubocop]
<% elsif @test_framework == :rspec -%>
task default: [:spec, :rubocop]
<% end -%>
```

In `data/templates/gem/bin/setup.erb`, append the hook-path line after `bundle install`:

```erb
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

bundle install
<% if @betterleaks -%>

git config core.hooksPath .githooks
<% end -%>
```

- [ ] **Step 6: Run the betterleaks tests to verify they pass**

Run: `bundle exec ruby -Itest -Ilib test/gempilot/cli/create_command_test.rb -n "/betterleaks/"`
Expected: PASS (7 tests — 6 presence/hooks-path + the omit test). The `run_create_command` helper already carries `--no-betterleaks` from Step 1, so the omit test does not prompt.

- [ ] **Step 7: Update the remaining non-interactive create invocations**

These run only in the full suite (Step 8), but each omits a betterleaks flag and would otherwise block on the prompt. In `test/gempilot/cli/create_command_test.rb`:
- `test_git_branch_flag_passes_branch_to_git_init` args: add `"--no-betterleaks",` before `"test_gem"`.
- `test_sh_runs_inside_unbundled_env` args: add `"--no-betterleaks",` before `"test_gem"`.
- `test_generated_gem_default_rake_task_passes` args: add `"--betterleaks",` before `"test_gem"` (exercises the default-on path end-to-end).
- `test_hyphenated_gem_default_rake_task_passes` args: add `"--betterleaks",` before `"gempilot-encryption"`.

In each of these 6 spec files, add `"--no-betterleaks",` into the create helper/`let` args array (alongside `"--no-git"`):
- `spec/gempilot/cli/commands/create_rakefile_spec.rb` (`def create`)
- `spec/gempilot/cli/commands/create_git_spec.rb` (`def create_with_git`)
- `spec/gempilot/cli/commands/create_rubocop_spec.rb` (`create_args` let)
- `spec/gempilot/cli/commands/create_test_helper_spec.rb` (`create_args` let)
- `spec/gempilot/cli/commands/create_loader_spec.rb` (`def create`)
- `spec/gempilot/cli/commands/create_validation_spec.rb` (`valid_opts` let)

- [ ] **Step 8: Run both full suites to verify green**

Run: `bundle exec rake test`
Expected: PASS, 0 failures/errors. (`test_generated_gem_default_rake_task_passes` and its hyphenated sibling now build a betterleaks-enabled gem and run `bundle exec rake` inside it — proving `Gempilot::BetterleaksTask.new` loads in a generated Rakefile and the default task still passes without the binary installed.)
Run: `bundle exec rake spec`
Expected: PASS, 0 failures.

- [ ] **Step 9: Verify rubocop is clean**

Run: `bundle exec rake rubocop`
Expected: `no offenses detected`.

- [ ] **Step 10: Commit**

```bash
git add lib/gempilot/cli/commands/create.rb lib/gempilot/cli/gem_builder.rb data/templates/gem/Rakefile.erb data/templates/gem/bin/setup.erb test/gempilot/cli/create_command_test.rb spec/gempilot/cli/commands/
git commit -m "Add default-on --[no-]betterleaks to gempilot create"
```

---

## Task 5: Dogfood betterleaks in gempilot's own repo + final verification

**Files:**
- Create: `/workspace/.githooks/pre-commit`
- Create: `/workspace/.github/workflows/secrets.yml`
- Modify: `/workspace/Rakefile`
- Modify: `/workspace/bin/setup`

- [ ] **Step 1: Add gempilot's own hook**

Create `/workspace/.githooks/pre-commit` with the exact content from Task 2 Step 1, then make it executable:

```bash
chmod +x .githooks/pre-commit
```

- [ ] **Step 2: Add gempilot's own secrets workflow**

Create `/workspace/.github/workflows/secrets.yml` with the exact content from Task 2 Step 2.

- [ ] **Step 3: Wire gempilot's Rakefile**

In `/workspace/Rakefile`, add `Gempilot::BetterleaksTask.new` immediately after the existing `Gempilot::VersionTask.new` line (the `require_relative "lib/gempilot"` already present makes the constant autoloadable — no explicit require needed):

```ruby
Gempilot::VersionTask.new
Gempilot::BetterleaksTask.new

task default: [:test, :spec, :rubocop]
```

- [ ] **Step 4: Wire gempilot's bin/setup**

Append to `/workspace/bin/setup` so fresh clones activate the hook:

```bash
git config core.hooksPath .githooks
```

- [ ] **Step 5: Activate and verify the hook degrades gracefully**

```bash
git config core.hooksPath .githooks
git commit --allow-empty -m "chore: probe pre-commit hook" && git reset --soft HEAD~1
```
Expected: the empty commit succeeds. If betterleaks is not installed, the hook prints the "not found on PATH; skipping" notice and exits 0; if it is installed, it scans the (empty) staged set and passes. Note: because the hook is now active for this repo, if betterleaks *is* installed and later flags a false positive in staged content, `git commit --no-verify` bypasses it.

- [ ] **Step 6: Verify `rake betterleaks` exists and degrades gracefully; confirm flags**

Run: `bundle exec rake betterleaks`
Expected: either a betterleaks scan report (if installed) or the "betterleaks not found on PATH; skipping secret scan" notice — never a Ruby error. If betterleaks is installed, confirm `betterleaks git --redact --verbose` and `betterleaks git --pre-commit --redact --staged --verbose` are accepted (run `betterleaks git --help` to double-check flag names).

- [ ] **Step 7: Full green suite**

Run: `bundle exec rake test && bundle exec rake spec && bundle exec rake rubocop && bundle exec rake zeitwerk:validate`
Expected: tests pass, specs pass, `no offenses detected`, `Zeitwerk: All files loaded successfully.`

- [ ] **Step 8: Commit**

```bash
git add .githooks/pre-commit .github/workflows/secrets.yml Rakefile bin/setup
git commit -m "Dogfood betterleaks scanning in gempilot's own repo"
```

- [ ] **Step 9: Mark the issues resolved**

In `issues.rec`, change `Status: open` to `Status: closed` for both `986E0100-88F4-11F1-B718-FE6CB9572C2D` (rbs) and `3FFE7616-88F5-11F1-8D3B-FE6CB9572C2D` (betterleaks). Commit:

```bash
git add issues.rec
git commit -m "Close rbs-mri and betterleaks issues"
```

- [ ] **Step 10: Update CLAUDE.md commands list**

Add a `gempilot setup` bullet to the Commands section of `/workspace/CLAUDE.md` (after the `destroy` entry):

```markdown
- `gempilot setup` — Retrofit an integration (e.g. betterleaks) into an existing gem
```

Commit:

```bash
git add CLAUDE.md
git commit -m "Document gempilot setup command"
```

---

## Self-review notes (spec coverage)

- **Issue A (rbs mri-only):** Task 1.
- **Artifact: pre-commit hook:** template (Task 2), rendered by create (Task 4), retrofit (Task 3), dogfood (Task 5).
- **Artifact: core.hooksPath:** create git-init (Task 4 Step 4b, asserted by `test_betterleaks_sets_hooks_path_on_git_init`), bin/setup template (Task 4 Step 5), setup command (Task 3), dogfood (Task 5).
- **Artifact: rake task:** `BetterleaksTask` (Task 2); wired in create/setup/dogfood.
- **Artifact: secrets.yml CI:** template (Task 2), create (Task 4), setup (Task 3), dogfood (Task 5).
- **Shared installer:** Task 3. Unit behavior (idempotent append incl. `skip` output, copy-if-absent under a given root) is covered by the setup-command tests (root `.`) and the create tests (root `@gem_name`); no separate host-only unit test is added since a mixin needs a host.
- **Error handling:** missing binary → graceful skip (Task 2 hook + task); not-in-gem → `GemContext` exit 1 (`test_setup_fails_without_gemspec`); unknown feature → exit 1 (`test_setup_fails_with_unknown_feature`); idempotency incl. `skip` output (`test_setup_betterleaks_is_idempotent`).
- **Default-on opt-out:** `--[no-]betterleaks` default ON via prompt/flag (Task 4).
- **Full-scan flag confirmation** (spec Risks): Task 5 Step 6.
- **Non-goal honored:** no `betterleaks.toml` shipped.
