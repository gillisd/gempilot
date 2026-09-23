# Command Generation Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `gempilot new command NAME` produce a command that actually runs: bootstrap the CommandKit plumbing the gem is missing (CLI router, base command, an executable that starts the router and is `chmod +x`, the `command_kit` runtime dependency followed by `bundle install`, and the Zeitwerk inflection that lets `cli.rb` define `CLI`), and give `gempilot create --exe` the same scaffold so a CLI gem works from its first commit.

**Architecture:** A new `Gempilot::CLI::CliBootstrap` mixin, shared by the `New` and `Create` commands, owns the scaffold. Every step is idempotent (it checks for the file, the dependency line, or the inflection before acting), so `new command` on an already-bootstrapped gem touches nothing, and running it twice is safe. Templates live in a new `data/templates/cli/` directory; `Generator#erb` gains a `from:` keyword so both commands can render them regardless of their own `template_dir`. `create --exe` now runs the bootstrap from inside the new gem instead of rendering the old bare executable, and the generated command test asserts something real (`command_name`) instead of `assert command`, which the generated gem's own RuboCop rejects.

**Tech Stack:** Ruby 4.0, command_kit 0.6 (`CommandKit::Commands`, `Commands::AutoLoad`, `Options::Version`, `Command#command_name`), Zeitwerk (`inflector.inflect("cli" => "CLI")`), ERB, Minitest (`test/`), RSpec (`spec/`), RuboCop with rubocop-claude.

**Issue:** `69816386-9F7F-11F1-8629-FE6CB9572C2F` — "Command generation is incomplete".

## Global Constraints

- Ruby `>= 4.0`; `it` block parameter is fine; `File.absolute_path?` etc. available.
- Double-quoted strings (`Style/StringLiterals: double_quotes`, single quotes allowed only when the string itself contains double quotes); NO `# frozen_string_literal:` comments; trailing commas in multiline literals/arguments; string constants end in `.freeze`.
- rdoc doc blocks in canonical form (a bare `##` line, then `# ...` lines); never a comment line that reads like code (`Claude/NoCommentedCode`, `MinLines: 1`); no `TODO`/`NOTE` in comments without attribution (`Claude/TaggedComments`) — `TODO` inside string literals is fine.
- Method bodies max 10 lines, ABC max 17, `Metrics/BlockLength` max 8 (heredoc/array/hash/method_call count as one); `Naming/PredicateMethod` forbids a method that only returns boolean literals unless it ends in `?` (which is why `insert_dependency` returns the path, not `true`).
- Zeitwerk: `lib/gempilot/cli/cli_bootstrap.rb` MUST define `Gempilot::CLI::CliBootstrap` (`spec/zeitwerk_spec.rb` eager-loads gempilot; the `cli` directory inflects to `CLI`, the file name to `CliBootstrap`).
- Generated files must pass the generated gem's own RuboCop (rubocop-claude included) and its Zeitwerk eager-load test; `Style/Documentation` needs a doc block on `class Deploy < Command`, `Style/ClassAndModuleChildren` is disabled in generated gems so `module My::Gem` compact style is fine.
- The generated gem's `.rubocop.yml` excludes `bin/*` but not `exe/`, so the executable is linted; its content mirrors gempilot's own `exe/gempilot`, which passes the same config.
- Verification: `bundle exec ruby -Itest -Ilib test/gempilot/cli/new_command_test.rb` (fast), `bundle exec ruby -Itest -Ilib test/gempilot/cli/create_command_test.rb` (includes integration tests that run `bundle exec rake` inside generated gems, ~2 minutes), `bundle exec rspec`, `bundle exec rubocop <files>`, and `bundle exec rake default` for the full gate.
- Baseline (verified 2026-09-23): minitest `109 runs, 4 failures` — the 4 are the Gemfile-template ordering regression fixed by Task 1 of `docs/superpowers/plans/2026-09-23-land-betterleaks-jruby.md`; apply that one-line change first, after which the baseline is `109 runs, 0 failures`, RSpec `192 examples, 0 failures`, RuboCop no offenses. Final state after this plan: minitest `128 runs, 0 failures`, RSpec `192 examples`, RuboCop no offenses.
- Commit messages: plain imperative sentences, no conventional-commit prefixes.

---

### Task 1: Shared generator helpers

**Files:**
- Modify: `lib/gempilot/cli/generator.rb` (add `update_file`, `ensure_directory`; extend `erb`)
- Modify: `lib/gempilot/cli/commands/new.rb` (delete its private `ensure_directory`)
- Create: `data/templates/cli/exe.erb` (needed by the new generator test; the other two CLI templates arrive in Task 2)
- Test: `test/gempilot/cli/generator_test.rb`

**Interfaces:**
- Consumes: `CommandKit::FileUtils#erb(source, dest = nil)` (super), `Generator#print_action`, `Generator#mkdir`.
- Produces: `Generator#update_file(path, content)` (prints `update`, writes), `Generator#ensure_directory(dir)` (prints `mkdir` only when creating), `Generator#erb(source, dest = nil, from: @template_dir)` (renders `File.join(from, source)`). Tasks 2–3 rely on all three.

- [ ] **Step 1: Write the failing tests**

In `test/gempilot/cli/generator_test.rb`, immediately before `def test_create_file_writes_content`, add:

```ruby
      def test_update_file_overwrites_content
        path = File.join(@tmpdir, "existing.rb")
        File.write(path, "old\n")
        @generator.update_file(path, "new\n")

        assert_equal "new\n", File.read(path)
        assert_includes @stdout.string, "update"
      end

      def test_ensure_directory_creates_a_missing_directory_once
        path = File.join(@tmpdir, "nested")
        @generator.ensure_directory(path)
        @generator.ensure_directory(path)

        assert_predicate Pathname(path), :directory?
        assert_equal 1, @stdout.string.scan("mkdir").size
      end

      def test_erb_renders_from_another_template_directory
        @generator.instance_variable_set(:@require_path, "test_gem")
        @generator.instance_variable_set(:@gem_module, "TestGem")
        dest = File.join(@tmpdir, "exe")
        @generator.erb("exe.erb", dest, from: File.join(Gempilot::ROOT, "data", "templates", "cli"))

        assert_includes File.read(dest), "TestGem::CLI.start"
      end
```

- [ ] **Step 2: Run them to verify they fail**

Run: `bundle exec ruby -Itest -Ilib test/gempilot/cli/generator_test.rb`
Expected: `12 runs, ... 3 errors` — `NoMethodError: undefined method 'update_file'`, `undefined method 'ensure_directory'`, and `ArgumentError: unknown keyword: :from`.

- [ ] **Step 3: Create the executable template**

Create `data/templates/cli/exe.erb` (this is gempilot's own `exe/gempilot`, parameterised):

```erb
#!/usr/bin/env ruby

gemfile = File.expand_path("../Gemfile", __dir__)

if File.exist?(gemfile)
  ENV["BUNDLE_GEMFILE"] ||= gemfile
  require "bundler/setup"
end

require "<%= @require_path %>/cli"

<%= @gem_module %>::CLI.start
```

- [ ] **Step 4: Extend Generator**

In `lib/gempilot/cli/generator.rb`, directly after `create_file`, add:

```ruby
      def update_file(path, content)
        print_action "update", path
        File.write(path, content)
      end

      def ensure_directory(dir)
        mkdir(dir) unless File.directory?(dir)
      end
```

and replace the existing `erb` method with:

```ruby
      # Renders +source+ from the command's template directory, or from the
      # directory given as +from+ for templates shared across commands.
      def erb(source, dest = nil, from: @template_dir)
        print_action("erb", dest, source: source) if dest

        super(File.join(from, source), dest)
      end
```

In `lib/gempilot/cli/commands/new.rb`, delete the now-duplicated private method:

```ruby
        def ensure_directory(dir)
          mkdir(dir) unless File.directory?(dir)
        end
```

(`New`'s other methods keep calling `ensure_directory`; it now comes from `Generator`.)

- [ ] **Step 5: Run the tests and rubocop**

Run: `bundle exec ruby -Itest -Ilib test/gempilot/cli/generator_test.rb && bundle exec ruby -Itest -Ilib test/gempilot/cli/new_command_test.rb && bundle exec rubocop lib/gempilot/cli/generator.rb lib/gempilot/cli/commands/new.rb test/gempilot/cli/generator_test.rb`
Expected: `12 runs, 0 failures, 0 errors`; `19 runs, 0 failures`; `3 files inspected, no offenses detected`.

- [ ] **Step 6: Commit**

```bash
git add lib/gempilot/cli/generator.rb lib/gempilot/cli/commands/new.rb data/templates/cli/exe.erb test/gempilot/cli/generator_test.rb
git commit -m "Add shared generator helpers for templates rendered by several commands"
```

---

### Task 2: `CliBootstrap` and `gempilot new command`

**Files:**
- Create: `lib/gempilot/cli/cli_bootstrap.rb`
- Create: `data/templates/cli/cli.rb.erb`, `data/templates/cli/command.rb.erb`
- Modify: `data/templates/new/command.rb.erb`
- Modify: `lib/gempilot/cli/commands/new.rb` (`include CliBootstrap`; `add_command` and the generated test content)
- Test: `test/gempilot/cli/new_command_test.rb`

**Interfaces:**
- Consumes: Task 1's `update_file`, `ensure_directory`, `erb(..., from:)`; `Generator#chmod`, `#sh`, `colors`; `@gem_name`, `@require_path`, `@gem_module` (set by `GemContext#detect_gem_context` in `New`).
- Produces: private `bootstrap_cli -> String | nil` (the gemspec path when it gained the `command_kit` dependency, so the caller knows a `bundle install` is due; `nil` otherwise). Constants `CliBootstrap::TEMPLATES`, `CLI_INFLECTION`, `TAP_SETUP`. Task 3 relies on `bootstrap_cli` being callable from `Create` with the same three ivars.

- [ ] **Step 1: Write the failing tests**

In `test/gempilot/cli/new_command_test.rb`, immediately before the `# --- Error handling ---` comment, add:

```ruby
      # --- CommandKit bootstrap ---

      def test_new_command_bootstraps_cli_router
        run_new_command("command", "deploy")
        content = File.read("lib/my_gem/cli.rb")

        assert_includes content, "class CLI"
        assert_includes content, "include CommandKit::Commands"
        assert_includes content, 'command_name "my_gem"'
        assert_includes content, "version MyGem::VERSION"
      end

      def test_new_command_bootstraps_base_command
        run_new_command("command", "deploy")
        content = File.read("lib/my_gem/cli/command.rb")

        assert_includes content, "class Command < CommandKit::Command"
        assert_includes content, "include CommandKit::Interactive"
      end

      def test_new_command_creates_executable_starting_the_cli
        run_new_command("command", "deploy")
        content = File.read("exe/my_gem")

        assert_predicate Pathname("exe/my_gem"), :executable?
        assert_includes content, 'require "my_gem/cli"'
        assert_includes content, "MyGem::CLI.start"
      end

      def test_new_command_makes_an_existing_executable_executable
        FileUtils.mkdir_p("exe")
        File.write("exe/my_gem", "#!/usr/bin/env ruby\nrequire \"my_gem/cli\"\nMyGem::CLI.start\n")
        run_new_command("command", "deploy")

        assert_predicate Pathname("exe/my_gem"), :executable?
        assert_equal "#!/usr/bin/env ruby\nrequire \"my_gem/cli\"\nMyGem::CLI.start\n", File.read("exe/my_gem")
      end

      def test_new_command_keeps_existing_cli_files
        FileUtils.mkdir_p("lib/my_gem/cli")
        File.write("lib/my_gem/cli.rb", "# custom router\n")
        File.write("lib/my_gem/cli/command.rb", "# custom base\n")
        run_new_command("command", "deploy")

        assert_equal "# custom router\n", File.read("lib/my_gem/cli.rb")
        assert_equal "# custom base\n", File.read("lib/my_gem/cli/command.rb")
      end

      def test_new_command_adds_command_kit_dependency_to_gemspec
        write_scaffolded_gem
        run_new_command("command", "deploy")
        gemspec = File.read("my_gem.gemspec")

        assert_includes gemspec, 'spec.add_dependency "command_kit"'
        assert_operator gemspec.index("command_kit"), :<, gemspec.index('"zeitwerk"')
      end

      def test_new_command_does_not_duplicate_command_kit_dependency
        write_scaffolded_gem
        run_new_command("command", "deploy")
        run_new_command("command", "status")

        assert_equal 1, File.read("my_gem.gemspec").scan("command_kit").size
      end

      def test_new_command_inflects_cli_in_the_loader
        write_scaffolded_gem
        run_new_command("command", "deploy")

        expected = <<~RUBY
          module MyGem
            LOADER = Zeitwerk::Loader.for_gem.tap do |l|
              l.inflector.inflect("cli" => "CLI")
              l.setup
            end
          end
        RUBY

        assert_includes File.read("lib/my_gem.rb"), expected
      end

      def test_new_command_inflects_cli_only_once
        write_scaffolded_gem
        run_new_command("command", "deploy")
        run_new_command("command", "status")

        assert_equal 1, File.read("lib/my_gem.rb").scan("inflect(").size
      end

      def test_new_command_bundles_when_the_dependency_was_added
        write_scaffolded_gem
        File.write("Gemfile", "source \"https://rubygems.org\"\ngemspec\n")
        sh_calls = run_new_command_recording_sh("command", "deploy")

        assert_includes sh_calls, ["bundle", "install"]
      end

      def test_new_command_does_not_bundle_when_the_dependency_was_present
        write_scaffolded_gem
        File.write("Gemfile", "source \"https://rubygems.org\"\ngemspec\n")
        run_new_command("command", "deploy")
        sh_calls = run_new_command_recording_sh("command", "status")

        assert_empty sh_calls
      end

      def test_new_command_in_hyphenated_gem_targets_the_nested_module
        FileUtils.rm("my_gem.gemspec")
        FileUtils.rm_rf("lib/my_gem")
        File.write("my-gem.gemspec", 'Gem::Specification.new { |s| s.name = "my-gem" }')
        FileUtils.mkdir_p("lib/my/gem")
        run_new_command("command", "deploy")

        assert_includes File.read("exe/my-gem"), 'require "my/gem/cli"'
        assert_includes File.read("exe/my-gem"), "My::Gem::CLI.start"
        assert_includes File.read("lib/my/gem/cli.rb"), "module My::Gem"
      end
```

and, after the existing private `run_new_command` helper at the bottom of the class, add:

```ruby
      def run_new_command_recording_sh(type, path)
        sh_calls = []
        command = Commands::New.new(stdout: StringIO.new)
        command.define_singleton_method(:sh) { |*args| sh_calls << args }
        command.main([type, path])
        sh_calls
      end

      def write_scaffolded_gem
        File.write("lib/my_gem.rb", <<~RUBY)
          require "zeitwerk"

          module MyGem
            LOADER = Zeitwerk::Loader.for_gem.tap(&:setup)
          end
        RUBY
        File.write("my_gem.gemspec", <<~RUBY)
          Gem::Specification.new do |spec|
            spec.name = "my_gem"
            spec.add_dependency "zeitwerk"
          end
        RUBY
      end
```

The file's default fixture is deliberately minimal (a one-line gemspec with no `add_dependency` line and no `lib/my_gem.rb`); those tests prove the bootstrap degrades to a printed hint instead of crashing, while `write_scaffolded_gem` provides the realistic shape for the dependency and inflection tests.

- [ ] **Step 2: Run them to verify they fail**

Run: `bundle exec ruby -Itest -Ilib test/gempilot/cli/new_command_test.rb`
Expected: `31 runs, ... 12 failures/errors` — `Errno::ENOENT` for `lib/my_gem/cli.rb`, `exe/my_gem`, etc., the gemspec/loader assertions fail, and `sh_calls` is empty where `["bundle", "install"]` is expected. The 19 pre-existing tests still pass.

- [ ] **Step 3: Create the CLI templates**

Create `data/templates/cli/cli.rb.erb`:

```erb
require "command_kit/commands"
require "command_kit/commands/auto_load"
require "command_kit/options/version"
require "<%= @require_path %>"

module <%= @gem_module %>
  ##
  # Top-level command router for the <%= @gem_name %> CLI.
  class CLI
    include CommandKit::Commands
    include CommandKit::Commands::AutoLoad.new(
      dir: "#{__dir__}/cli/commands",
      namespace: "#{self}::Commands",
    )
    include CommandKit::Options::Version

    command_name "<%= @gem_name %>"
    version <%= @gem_module %>::VERSION
  end
end
```

Create `data/templates/cli/command.rb.erb`:

```erb
require "command_kit/command"
require "command_kit/colors"
require "command_kit/interactive"

module <%= @gem_module %>
  class CLI
    ##
    # Base command class for all <%= @gem_name %> subcommands.
    class Command < CommandKit::Command
      include CommandKit::Colors
      include CommandKit::Interactive
    end
  end
end
```

(`CommandKit::BugReport` is left out on purpose: it needs a `bug_report_url`, which gempilot cannot know for someone else's gem.)

Replace the contents of `data/templates/new/command.rb.erb` with (only the doc block is new; the generated gem's `Style/Documentation` cop requires it):

```erb
require_relative "../command"

module <%= @gem_module %>
  class CLI
    module Commands
      ##
      # The <%= @command_file_name %> command.
      class <%= @command_name %> < Command
        description "TODO: describe the <%= @command_file_name %> command"

        def run
          puts "TODO: implement <%= @command_file_name %>"
        end
      end
    end
  end
end
```

- [ ] **Step 4: Create the bootstrap mixin**

Create `lib/gempilot/cli/cli_bootstrap.rb`:

```ruby
module Gempilot
  class CLI
    ##
    # Scaffolds the CommandKit plumbing a generated command needs and the gem
    # is missing: the +CLI+ router, the base +Command+ class, an executable
    # that starts the router, the Zeitwerk inflection letting +cli.rb+ define
    # +CLI+ rather than +Cli+, and the +command_kit+ runtime dependency.
    #
    # Every step is idempotent, so a gem that already has any of these pieces
    # keeps them untouched. Expects the including command to provide the
    # Generator methods and +@gem_name+, +@require_path+, and +@gem_module+.
    module CliBootstrap
      TEMPLATES = Gempilot::ROOT.join("data", "templates", "cli").to_s.freeze
      CLI_INFLECTION = 'l.inflector.inflect("cli" => "CLI")'.freeze
      TAP_SETUP = ".tap(&:setup)".freeze

      private

      # Returns the gemspec path when it gained the command_kit dependency
      # (so the caller knows a bundle install is due), nil otherwise.
      def bootstrap_cli
        create_cli_router
        create_base_command
        create_executable
        inflect_cli_constant
        add_command_kit_dependency
      end

      def create_cli_router
        render_once "cli.rb.erb", File.join("lib", @require_path, "cli.rb")
      end

      def create_base_command
        render_once "command.rb.erb", File.join("lib", @require_path, "cli", "command.rb")
      end

      def render_once(template, path)
        return if File.exist?(path)

        ensure_directory(File.dirname(path))
        erb template, path, from: TEMPLATES
      end

      def create_executable
        path = File.join("exe", @gem_name)
        render_once "exe.erb", path
        chmod "+x", path unless File.executable?(path)
        return if File.read(path).include?("CLI.start")

        puts colors.yellow("#{path} does not start #{@gem_module}::CLI; add `#{@gem_module}::CLI.start` to it.")
      end

      def inflect_cli_constant
        path = File.join("lib", "#{@require_path}.rb")
        source = File.exist?(path) ? File.read(path) : ""
        return if source.include?(CLI_INFLECTION)

        line = source.lines.find { it.include?(TAP_SETUP) }
        return hint_inflection(path) unless line

        update_file path, source.sub(TAP_SETUP, inflection_block(indent_of(line)))
      end

      def inflection_block(indent)
        [".tap do |l|", "#{indent}  #{CLI_INFLECTION}", "#{indent}  l.setup", "#{indent}end"].join("\n")
      end

      def indent_of(line)
        line[0, line.length - line.lstrip.length]
      end

      def hint_inflection(path)
        puts colors.yellow("Could not find #{TAP_SETUP} in #{path}; add #{CLI_INFLECTION} before the loader's setup.")
      end

      def add_command_kit_dependency
        path = "#{@gem_name}.gemspec"
        lines = File.readlines(path)
        return if lines.any? { it.include?("command_kit") }

        index = lines.index { it.include?(".add_dependency") } || lines.rindex { it.strip == "end" }
        index ? insert_dependency(path, lines, index) : hint_dependency(path)
      end

      def insert_dependency(path, lines, index)
        lines.insert(index, %(  #{gemspec_receiver(lines)}.add_dependency "command_kit"\n))
        update_file path, lines.join
        path
      end

      def gemspec_receiver(lines)
        line = lines.find { it.include?(".add_dependency") }
        line ? line.strip[0, line.strip.index(".add_dependency")] : "spec"
      end

      def hint_dependency(path)
        puts colors.yellow("Could not add command_kit to #{path}; add `spec.add_dependency \"command_kit\"` yourself.")
      end
    end
  end
end
```

Why each piece looks the way it does:
- The inflection is mandatory, not cosmetic: Zeitwerk expects `lib/my_gem/cli.rb` to define `MyGem::Cli`; without `inflect("cli" => "CLI")` the gem's eager-load test and `rake zeitwerk:validate` fail with `Zeitwerk::NameError`. The edit turns the templates' `.tap(&:setup)` into the block form and indents relative to the `LOADER` line, so it is correct for both `for_gem` (2 spaces) and `for_gem_extension` (4 spaces). Only plain string operations are used (`include?`, `sub` with a String pattern, `lines`); no regex.
- The dependency goes before the first existing `.add_dependency` line (alphabetical for the generated gemspec, which has `zeitwerk`) using that line's receiver, or before the closing `end`; a gemspec with neither gets a hint instead of a broken edit.
- `insert_dependency` returns the path (truthy) rather than `true` because `Naming/PredicateMethod` rejects boolean-literal returns from methods not ending in `?`.

- [ ] **Step 5: Wire the bootstrap into `New`**

In `lib/gempilot/cli/commands/new.rb` add the include after `include GemContext`:

```ruby
        include Generator
        include GemContext
        include CliBootstrap
```

Replace the `add_command` method with these three methods:

```ruby
        def add_command(name)
          name = name.split("::").last if name.include?("::")
          @command_file_name = name.underscore
          @command_name = name.camelize

          print_adding_banner("command", @command_name)
          dependency_added = bootstrap_cli
          write_command_files
          bundle_install if dependency_added
        end

        def write_command_files
          file_path = File.join("lib", @require_path, "cli", "commands", "#{@command_file_name}.rb")
          ensure_directory(File.dirname(file_path))
          erb "command.rb.erb", file_path
          add_command_test_file(@command_name, @command_file_name)
        end

        def bundle_install
          return unless File.exist?("Gemfile")

          sh "bundle", "install"
        end
```

Replace `rspec_command_content` and `minitest_command_content` with versions that assert something the generated gem's RuboCop accepts (the old `assert command` trips `Minitest/UselessAssertion`), and add `command_line_name`:

```ruby
        def rspec_command_content(command_name)
          <<~RUBY
            require "spec_helper"

            RSpec.describe #{@gem_module}::CLI::Commands::#{command_name} do
              it "is registered under its command name" do
                expect(described_class.command_name).to eq("#{command_line_name}")
              end
            end
          RUBY
        end

        def minitest_command_content(command_name)
          <<~RUBY
            require "test_helper"
            require "#{@require_path}/cli"

            module #{@gem_module}
              class CLI
                class #{command_name}Test < Minitest::Test
                  def test_command_name
                    assert_equal "#{command_line_name}", Commands::#{command_name}.command_name
                  end
                end
              end
            end
          RUBY
        end

        # The name CommandKit registers the command under: dashes, not
        # underscores, matching how AutoLoad maps the file name.
        def command_line_name
          @command_file_name.tr("_", "-")
        end
```

(`CommandKit::Command.command_name` defaults to the dasherized, demodulized class name, which is exactly what `Commands::AutoLoad` derives from the file name, so `DeployNow` in `deploy_now.rb` is `deploy-now` on both sides.)

- [ ] **Step 6: Run the tests, the new-command specs, and rubocop**

Run: `bundle exec ruby -Itest -Ilib test/gempilot/cli/new_command_test.rb && bundle exec rspec spec/gempilot/cli/commands/new_namespace_spec.rb spec/gempilot/cli/commands/new_interactive_spec.rb spec/zeitwerk_spec.rb --no-color && bundle exec rubocop lib/gempilot/cli/cli_bootstrap.rb lib/gempilot/cli/commands/new.rb test/gempilot/cli/new_command_test.rb`
Expected: `31 runs, 0 failures, 0 errors`; `13 examples, 0 failures`; `3 files inspected, no offenses detected`.

- [ ] **Step 7: Commit**

```bash
git add lib/gempilot/cli/cli_bootstrap.rb lib/gempilot/cli/commands/new.rb data/templates/cli data/templates/new/command.rb.erb test/gempilot/cli/new_command_test.rb
git commit -m "Bootstrap a CommandKit CLI when generating a command"
```

---

### Task 3: `gempilot create --exe` builds the same CLI

**Files:**
- Modify: `lib/gempilot/cli/commands/create.rb` (`include CliBootstrap`, `@gem_module`, option description)
- Modify: `lib/gempilot/cli/gem_builder.rb` (`render_executable`, doc block)
- Delete: `data/templates/gem/exe/gem_name.erb`
- Test: `test/gempilot/cli/create_command_test.rb`

**Interfaces:**
- Consumes: `bootstrap_cli` (Task 2), `GemBuilder#cd` (from `CommandKit::FileUtils`), `@module_name` computed in `Create#derive_naming`.
- Produces: `create --exe` output containing `lib/<gem>/cli.rb`, `lib/<gem>/cli/command.rb`, `exe/<gem>` (executable, starts `<Module>::CLI`), a gemspec with `spec.add_dependency "command_kit"`, and the loader inflection; `create` without `--exe` is unchanged.

- [ ] **Step 1: Write the failing tests**

In `test/gempilot/cli/create_command_test.rb`, immediately before `def test_inflects_module_name_correctly`, add:

```ruby
      def test_exe_flag_bootstraps_a_command_kit_cli
        run_create_command("test_gem", "--exe")

        assert_includes File.read("test_gem/exe/test_gem"), "TestGem::CLI.start"
        assert_includes File.read("test_gem/lib/test_gem/cli.rb"), "class CLI"
        assert_includes File.read("test_gem/lib/test_gem/cli/command.rb"), "class Command < CommandKit::Command"
        assert_includes File.read("test_gem/test_gem.gemspec"), 'spec.add_dependency "command_kit"'
        assert_includes File.read("test_gem/lib/test_gem.rb"), 'l.inflector.inflect("cli" => "CLI")'
      end

      def test_no_exe_flag_leaves_the_cli_out
        run_create_command("test_gem")

        refute_path_exists "test_gem/lib/test_gem/cli.rb"
        refute_includes File.read("test_gem/test_gem.gemspec"), "command_kit"
        assert_includes File.read("test_gem/lib/test_gem.rb"), "for_gem.tap(&:setup)"
      end

      def test_hyphenated_gem_exe_flag_targets_the_extension_module
        run_create_command("gempilot-encryption", "--exe")
        exe = File.read("gempilot-encryption/exe/gempilot-encryption")
        entry = File.read("gempilot-encryption/lib/gempilot/encryption.rb")
        expected_loader = [
          "    LOADER = Zeitwerk::Loader.for_gem_extension(Gempilot).tap do |l|",
          '      l.inflector.inflect("cli" => "CLI")',
          "      l.setup",
          "    end",
        ].join("\n")

        assert_includes exe, 'require "gempilot/encryption/cli"'
        assert_includes exe, "Gempilot::Encryption::CLI.start"
        assert_includes entry, expected_loader
      end
```

and, immediately before the `private` keyword at the bottom of the class, the end-to-end test:

```ruby
      def test_generated_cli_gem_runs_end_to_end
        stdout = StringIO.new
        Commands::Create.new(stdout: stdout).main(cli_gem_args)
        patch_gemfile_gempilot_path("cli_gem/Gemfile")

        Dir.chdir("cli_gem") do
          Commands::New.new(stdout: stdout).main(["command", "deploy"])

          Bundler.with_unbundled_env do
            output = `bundle exec rake 2>&1`

            assert_equal 0, $CHILD_STATUS.exitstatus, "Default rake task failed in CLI gem:\n#{output}"
            assert_equal "cli_gem 0.0.1", `bundle exec exe/cli_gem --version 2>&1`.strip
            assert_equal "TODO: implement deploy", `bundle exec exe/cli_gem deploy 2>&1`.strip
          end
        end
      end
```

then, right after `private`, the argument helper:

```ruby
      def cli_gem_args
        ["--author", "Test Author", "--email", "test@example.com", "--summary", "A test gem",
         "--ruby-version", RUBY_VERSION, "--test", "minitest", "--exe", "--no-git", "cli_gem"]
      end
```

The end-to-end test mirrors the existing `*_default_rake_task_passes` tests (real `bundle install`, Gemfile patched to the checkout) and additionally generates a command and runs the executable, so it proves the whole scaffold: Zeitwerk eager-loads the CLI files, the gem's RuboCop accepts them, `--version` prints `cli_gem 0.0.1`, and `deploy` dispatches through `AutoLoad`.

- [ ] **Step 2: Run the unit tests to verify they fail**

Run: `bundle exec ruby -Itest -Ilib test/gempilot/cli/create_command_test.rb -n "/exe_flag|cli_gem/"`
Expected: 4 runs; `test_exe_flag_bootstraps_a_command_kit_cli`, `test_hyphenated_gem_exe_flag_targets_the_extension_module` and the end-to-end test fail (`Errno::ENOENT` for `lib/test_gem/cli.rb`; the executable command is unknown), `test_no_exe_flag_leaves_the_cli_out` already passes.

- [ ] **Step 3: Wire the bootstrap into `Create`**

In `lib/gempilot/cli/commands/create.rb`:

```ruby
        include Generator
        include GemBuilder
        include CliBootstrap
```

change the option description:

```ruby
        option :exe, long: "--[no-]exe", desc: "Create a CommandKit CLI with an executable"
```

and in `derive_naming` set the ivar the CLI templates use, right after `@module_name`:

```ruby
          @module_name = @require_path.camelize
          @gem_module = @module_name
          @module_parts = @module_name.split("::")
```

In `lib/gempilot/cli/gem_builder.rb` replace `render_executable` with:

```ruby
      # The executable is one piece of the CommandKit CLI, so the whole
      # scaffold (router, base command, exe, inflection, dependency) comes
      # from CliBootstrap, run from inside the new gem.
      def render_executable
        return unless options[:exe]

        cd(@gem_name) { bootstrap_cli }
      end
```

and extend the module doc's ivar list:

```ruby
    ## +@gem_name+, +@require_path+, +@module_name+, +@gem_module+,
    ## +@hyphenated+, +@test_framework+, +@branch+.
```

Delete `data/templates/gem/exe/gem_name.erb` (`git rm data/templates/gem/exe/gem_name.erb`); `data/templates/cli/exe.erb` replaces it. `create_directories` keeps creating `exe/` up front so the printed scaffold listing is unchanged; `render_executable` runs before `run_bundle_install`, so the `command_kit` dependency the bootstrap adds is installed by create's own `bundle install`.

- [ ] **Step 4: Run the whole create test file, then the full gate**

Run: `bundle exec ruby -Itest -Ilib test/gempilot/cli/create_command_test.rb`
Expected: `57 runs, 0 failures, 0 errors` (this includes the three integration tests; allow a couple of minutes).

Run: `bundle exec rake default 2>&1 | tail -8`
Expected: minitest `128 runs, 0 failures`, RSpec `192 examples, 0 failures`, RuboCop `no offenses detected`.

- [ ] **Step 5: Commit**

```bash
git add lib/gempilot/cli/commands/create.rb lib/gempilot/cli/gem_builder.rb data/templates/gem/exe/gem_name.erb test/gempilot/cli/create_command_test.rb
git commit -m "Scaffold the CommandKit CLI for create --exe"
```

---

### Task 4: Documentation

**Files:**
- Modify: `README.md` (`gempilot create` options table, `gempilot new` section, Generated Gem Features)
- Modify: `CLAUDE.md` (Commands and Architecture lists)

**Interfaces:**
- Consumes: final behaviour of Tasks 2–3. No code.

- [ ] **Step 1: README**

In the `gempilot create` options table change the `--[no-]exe` row to:

```markdown
| `--[no-]exe` | Create a CommandKit CLI: `exe/<gem>`, `lib/<gem>/cli.rb`, base command, `command_kit` dependency | prompted |
```

Replace the paragraph under the `gempilot new` code block with:

```markdown
Creates the source file under `lib/` and a corresponding test file. For
commands, generates a CommandKit command class in `lib/<gem>/cli/commands/`
and, the first time, bootstraps the CLI around it: `lib/<gem>/cli.rb` (the
router), `lib/<gem>/cli/command.rb` (the base class), an executable
`exe/<gem>` that starts the router, the `command_kit` dependency in the
gemspec (followed by `bundle install`), and the Zeitwerk inflection
`"cli" => "CLI"` in `lib/<gem>.rb`. Pieces that already exist are left alone.
```

In "Generated Gem Features" add, after the Zeitwerk bullet:

```markdown
- **CommandKit CLI** when created with `--exe`: router, base command, and an
  executable that works from the first commit
```

- [ ] **Step 2: CLAUDE.md**

Change the `gempilot new` command bullet to:

```markdown
- `gempilot new` — Generate a class, module, or command in an existing gem (templates in `data/templates/new/`); generating a command also bootstraps the CommandKit CLI when it is missing
```

and the `gempilot create` bullet to:

```markdown
- `gempilot create` — Scaffold a new gem (templates in `data/templates/gem/`); `--exe` adds a CommandKit CLI
```

Add to the Architecture list, after the `GemContext` bullet:

```markdown
- `CliBootstrap` module (`lib/gempilot/cli/cli_bootstrap.rb`) shared by `create --exe` and `new command`: idempotently scaffolds `lib/<gem>/cli.rb`, `lib/<gem>/cli/command.rb`, `exe/<gem>` (chmod +x), the `command_kit` gemspec dependency, and the `"cli" => "CLI"` loader inflection; its templates live in `data/templates/cli/` and are rendered through `Generator#erb(..., from:)`
```

- [ ] **Step 3: Commit**

```bash
git add README.md CLAUDE.md
git commit -m "Document the CommandKit CLI bootstrap"
```
