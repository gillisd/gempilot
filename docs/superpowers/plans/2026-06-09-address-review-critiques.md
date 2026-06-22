# Address Code-Review Critiques Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Retire a class of namespace/path bugs and the `new`/`destroy` duplication by introducing a `GemConstant` value object, plus small polish to the version tasks, framework detection, and stale docs.

**Architecture:** Extract the duplicated "constant within a gem" logic (qualify, namespaces, lib/test paths) out of `new.rb`, `destroy.rb`, and `gem_context.rb` into one immutable `Gempilot::GemConstant` (a `Data` subclass), mirroring the existing `Project::Version` value object. Commands build a `GemConstant` via a shared `GemContext#gem_constant` factory and read paths off it. Smaller, independent fixes round out the other critiques.

**Tech Stack:** Ruby 4.0, CommandKit, Zeitwerk, RSpec 3.13 + Minitest, RuboCop (+ rubocop-rspec).

---

## Environment note

`bundle exec` is broken on this box (vendored gems are macOS-built; see memory `gempilot-test-running-env`). Run tools directly against system gems:
- RSpec: `rspec <path>` (full suite: `rspec`)
- Minitest: `ruby -Itest -Ilib -e 'Dir["test/**/*_test.rb"].each { |f| require File.expand_path(f) }'`
- RuboCop: `rubocop <paths>`

In a normal environment these are `bundle exec rspec` / `bundle exec rake test` / `bundle exec rake rubocop`.

## File structure

| File | Responsibility | Change |
|---|---|---|
| `lib/gempilot/gem_constant.rb` | Value object: a class/module constant within a gem (qualify + paths) | **Create** |
| `spec/gempilot/gem_constant_spec.rb` | Unit spec for `GemConstant` | **Create** |
| `lib/gempilot/cli/gem_context.rb` | Shared command context; `gem_constant` factory + framework detection | Modify |
| `lib/gempilot/cli/commands/new.rb` | `new` command, now delegating constant logic to `GemConstant` | Modify |
| `lib/gempilot/cli/commands/destroy.rb` | `destroy` command, same delegation | Modify |
| `lib/gempilot/version_tag.rb` | Version git ops: consistent error + named constant | Modify |
| `spec/gempilot/version_tag_spec.rb` | Update the non-bump assertion expectation | Modify |
| `spec/gempilot/cli/commands/new_namespace_spec.rb` | Document unified non-interactive rooting | Modify |
| `CLAUDE.md` | Fix stale architecture/feature notes | Modify |

**Design decision (documented in `GemConstant`):** every class/module constant is rooted at the gem's module *by construction* — bare input is prefixed, input already starting with the gem's first segment is left as-is. This makes interactive and non-interactive behavior consistent and removes the half-enforced `validate_gem_root!` (no test depends on its rejection). Rooting matches on the first segment only, preserving extension-gem support (a `My::Gem` gem accepts any `My::…`).

---

## Part A — Version task polish

### Task A1: Make the non-bump guard `raise` instead of `abort`

**Files:**
- Modify: `lib/gempilot/version_tag.rb:50`
- Test: `spec/gempilot/version_tag_spec.rb:109-118`

- [ ] **Step 1: Update the spec to expect a `RuntimeError`** (consistent with `#create`'s dirty-staging error)

In `spec/gempilot/version_tag_spec.rb`, replace the block at lines 109-118 with:

```ruby
  describe "#tag when last commit is not a version bump" do
    before do
      File.write("README.md", "init")
      system("git add README.md && git commit -m 'Not a version bump' --quiet")
    end

    it "raises an error" do
      expect { version_tag.tag }.to raise_error(RuntimeError, /does not appear to be a version bump/)
    end
  end
```

- [ ] **Step 2: Run the spec, verify it fails**

Run: `rspec spec/gempilot/version_tag_spec.rb -e "not a version bump"`
Expected: FAIL — `expected RuntimeError, got #<SystemExit: exit>` (code still calls `abort`).

- [ ] **Step 3: Change `abort` to `raise`**

In `lib/gempilot/version_tag.rb`, in `assert_last_commit_is_bump!` (line 50), change:

```ruby
      abort "Last commit does not appear to be a version bump." unless message.start_with?("Bump version to ")
```
to:
```ruby
      raise "Last commit does not appear to be a version bump." unless message.start_with?("Bump version to ")
```

- [ ] **Step 4: Run the spec, verify it passes**

Run: `rspec spec/gempilot/version_tag_spec.rb`
Expected: PASS (all examples).

- [ ] **Step 5: Commit**

```bash
git add lib/gempilot/version_tag.rb spec/gempilot/version_tag_spec.rb
git commit -m "Raise instead of abort in version bump guard"
```

### Task A2: Extract the bump-message prefix into a named constant

**Files:**
- Modify: `lib/gempilot/version_tag.rb`

- [ ] **Step 1: Confirm current behavior is covered, run the spec**

Run: `rspec spec/gempilot/version_tag_spec.rb`
Expected: PASS. (`#create` asserts the commit message; the guard test asserts the prefix check — both cover this refactor.)

- [ ] **Step 2: Add the constant and use it in both places**

In `lib/gempilot/version_tag.rb`, add the constant just below `include StrictShell`:

```ruby
    include StrictShell

    ## Commit-message prefix written for a version bump; the guard below
    ## matches on it, so the two must stay in sync.
    BUMP_MESSAGE_PREFIX = "Bump version to ".freeze
```

In `#create`, change the commit line to:

```ruby
      sh "git", "commit", "-m", "#{BUMP_MESSAGE_PREFIX}#{version.value}"
```

In `assert_last_commit_is_bump!`, change the guard to:

```ruby
      raise "Last commit does not appear to be a version bump." unless message.start_with?(BUMP_MESSAGE_PREFIX)
```

- [ ] **Step 3: Run the spec, verify still green**

Run: `rspec spec/gempilot/version_tag_spec.rb`
Expected: PASS (commit message is byte-identical: `"Bump version to <value>"`).

- [ ] **Step 4: Lint and commit**

```bash
rubocop lib/gempilot/version_tag.rb
git add lib/gempilot/version_tag.rb
git commit -m "Name the version bump commit-message prefix"
```

---

## Part B — `GemConstant` value object + de-duplicate new/destroy

### Task B1: Create the `GemConstant` value object

**Files:**
- Create: `lib/gempilot/gem_constant.rb`
- Test: `spec/gempilot/gem_constant_spec.rb`

- [ ] **Step 1: Write the unit spec**

Create `spec/gempilot/gem_constant_spec.rb`:

```ruby
require "spec_helper"

RSpec.describe Gempilot::GemConstant do
  def constant(input, gem_module: "MyGem", require_path: "my_gem")
    described_class.new(input: input, gem_module: gem_module, require_path: require_path)
  end

  describe "#qualified" do
    it "prepends the gem module to a bare suffix" do
      expect(constant("Services::Auth").qualified).to eq("MyGem::Services::Auth")
    end

    it "leaves an already-rooted constant unchanged" do
      expect(constant("MyGem::Services::Auth").qualified).to eq("MyGem::Services::Auth")
    end

    it "matches on the root segment for multi-segment modules" do
      c = constant("My::Widget", gem_module: "My::Gem", require_path: "my/gem")
      expect(c.qualified).to eq("My::Widget")
    end

    it "prepends the full module to a bare suffix under a multi-segment module" do
      c = constant("Widget", gem_module: "My::Gem", require_path: "my/gem")
      expect(c.qualified).to eq("My::Gem::Widget")
    end
  end

  describe "#namespaces / #name" do
    it "splits the qualified constant", :aggregate_failures do
      c = constant("Services::Auth")
      expect(c.namespaces).to eq(%w[MyGem Services])
      expect(c.name).to eq("Auth")
    end
  end

  describe "#lib_path" do
    it "builds the underscored source path" do
      expect(constant("Services::Auth").lib_path).to eq("lib/my_gem/services/auth.rb")
    end
  end

  describe "#test_path" do
    it "builds the rspec path" do
      expect(constant("Services::Auth").test_path(:rspec)).to eq("spec/my_gem/services/auth_spec.rb")
    end

    it "builds the minitest path" do
      expect(constant("Services::Auth").test_path(:minitest)).to eq("test/my_gem/services/auth_test.rb")
    end

    it "does not duplicate segments for multi-segment (hyphenated) modules" do
      c = constant("Widget", gem_module: "My::Gem", require_path: "my/gem")
      expect(c.test_path(:minitest)).to eq("test/my/gem/widget_test.rb")
    end
  end
end
```

- [ ] **Step 2: Run the spec, verify it fails**

Run: `rspec spec/gempilot/gem_constant_spec.rb`
Expected: FAIL — `uninitialized constant Gempilot::GemConstant`.

- [ ] **Step 3: Create the value object**

Create `lib/gempilot/gem_constant.rb`:

```ruby
module Gempilot
  ## A class or module constant resolved within a gem's namespace.
  ##
  ## Wraps raw user input (a bare suffix like +Services::Auth+ or a
  ## fully-qualified +MyGem::Services::Auth+) together with the gem's module
  ## and require path, and derives the qualified constant, file paths, and
  ## namespace pieces from a single parse.
  ##
  ## Every constant is rooted at the gem's module: bare input is prefixed with
  ## it, while input already starting with the gem's root segment is left as
  ## is. Rooting is matched on the first segment only, so an extension gem
  ## whose module is +My::Gem+ accepts any +My::...+ constant.
  class GemConstant < Data.define(:input, :gem_module, :require_path)
    using String::Inflectable

    ## The fully-qualified constant, rooted at the gem module.
    def qualified
      input.start_with?("#{root_segment}::") ? input : "#{gem_module}::#{input}"
    end

    ## Namespace segments preceding the final constant name.
    def namespaces
      parts[0...-1]
    end

    ## The final class or module name.
    def name
      parts.last
    end

    ## Path to the constant's source file, e.g. +lib/my_gem/services/auth.rb+.
    def lib_path
      "#{File.join("lib", *path_segments)}.rb"
    end

    ## Path to the constant's test file for +framework+ (+:rspec+ or
    ## +:minitest+); correct for multi-segment (hyphenated) gem modules.
    def test_path(framework)
      rest = path_segments.drop(require_path.split("/").length)
      if framework == :rspec
        "#{File.join("spec", require_path, *rest)}_spec.rb"
      else
        "#{File.join("test", require_path, *rest)}_test.rb"
      end
    end

    private

    def root_segment
      gem_module.split("::").first
    end

    def parts
      qualified.split("::")
    end

    def path_segments
      parts.map(&:underscore)
    end
  end
end
```

- [ ] **Step 4: Run the spec, verify it passes**

Run: `rspec spec/gempilot/gem_constant_spec.rb`
Expected: PASS (all examples). If you see `undefined method 'underscore'`, confirm `String::Inflectable` is loaded at boot (it is for `new.rb`); the file-top `using` activates it for the whole file.

- [ ] **Step 5: Lint and commit**

```bash
rubocop lib/gempilot/gem_constant.rb spec/gempilot/gem_constant_spec.rb
git add lib/gempilot/gem_constant.rb spec/gempilot/gem_constant_spec.rb
git commit -m "Add GemConstant value object for gem-rooted constants"
```

### Task B2: Add a `gem_constant` factory to `GemContext`

**Files:**
- Modify: `lib/gempilot/cli/gem_context.rb`

- [ ] **Step 1: Add the factory method** (additive; `parse_constant`/`validate_gem_root!` stay for now so nothing breaks)

In `lib/gempilot/cli/gem_context.rb`, add this method inside `module GemContext` (after `detect_gem_context`):

```ruby
      def gem_constant(input)
        GemConstant.new(input: input, gem_module: @gem_module, require_path: @require_path)
      end
```

- [ ] **Step 2: Verify nothing is broken**

Run: `rspec`
Expected: PASS (additive change; existing suite unaffected).

- [ ] **Step 3: Commit**

```bash
git add lib/gempilot/cli/gem_context.rb
git commit -m "Add GemContext#gem_constant factory"
```

### Task B3: Refactor `new` to use `GemConstant`

**Files:**
- Modify: `lib/gempilot/cli/commands/new.rb`
- Test: `spec/gempilot/cli/commands/new_namespace_spec.rb`

- [ ] **Step 1: Add a spec for unified non-interactive rooting** (documents the now-consistent behavior: a bare name passed as an argument is rooted, instead of being rejected)

In `spec/gempilot/cli/commands/new_namespace_spec.rb`, add this context inside the top-level `describe` (the file already has the tmpdir `around` + `include FileUtils` + `my_gem` gemspec fixture):

```ruby
  describe "non-interactive rooting" do
    before { mkdir_p("lib/my_gem") }

    it "roots a bare class name under the gem module" do
      command.main(["class", "Services::Auth"])

      expect(File).to exist("lib/my_gem/services/auth.rb")
    end
  end
```

- [ ] **Step 2: Run it, verify it fails**

Run: `rspec spec/gempilot/cli/commands/new_namespace_spec.rb -e "roots a bare class name"`
Expected: FAIL — current code calls `validate_gem_root!("Services")` and exits, so the file is not created (`SystemExit`).

- [ ] **Step 3: Refactor `new.rb`**

In `lib/gempilot/cli/commands/new.rb`:

Replace `prompt_for_path` (it no longer prepends — `GemConstant#qualified` owns that):

```ruby
        def prompt_for_path(type)
          ask(colors.green(type), required: true)
        end
```

Replace `dispatch_add` so class/module build a `GemConstant`:

```ruby
        def dispatch_add(type, path)
          case type
          when "class"   then add_class(gem_constant(path))
          when "module"  then add_module(gem_constant(path))
          when "command" then add_command(path)
          else
            puts colors.red("Unknown type '#{type}'. Use class, module, or command.")
            exit 1
          end
        end
```

Delete `prepare_constant` and `class_test_path` entirely. Replace `add_class`, `add_module`, and `add_test_file` with:

```ruby
        def add_class(constant)
          print_adding_banner("class", constant.qualified)
          ensure_directory(File.dirname(constant.lib_path))
          source = build_nested_source(constant.namespaces, "class", constant.name)
          create_file(constant.lib_path, source)
          add_test_file(constant)
        end

        def add_module(constant)
          print_adding_banner("module", constant.qualified)
          ensure_directory(File.dirname(constant.lib_path))
          source = build_nested_source(constant.namespaces, "module", constant.name)
          create_file(constant.lib_path, source)
        end

        def add_test_file(constant)
          test_path = constant.test_path(@test_framework)
          ensure_directory(File.dirname(test_path))
          content = if @test_framework == :rspec
                      rspec_class_content(constant.namespaces, constant.name)
                    else
                      minitest_class_content(constant.namespaces, constant.name)
                    end
          create_file(test_path, content)
        end
```

Leave `add_command`, `command_test_path`, `add_command_test_file`, `rspec_class_content`, `minitest_class_content`, `rspec_command_content`, `minitest_command_content`, `build_nested_source`, `build_namespace_lines`, `build_closing_lines`, `print_adding_banner`, and `ensure_directory` unchanged.

- [ ] **Step 4: Run the new test, the command specs, and the minitest suite**

Run: `rspec spec/gempilot/cli/commands/new_namespace_spec.rb spec/gempilot/cli/commands/new_interactive_spec.rb`
Expected: PASS (interactive + hyphenated cases still green; new rooting test green).

Run: `ruby -Itest -Ilib -e 'require File.expand_path("test/gempilot/cli/new_command_test.rb")'`
Expected: PASS, 0 failures (full constants are unchanged by `qualified`).

- [ ] **Step 5: Lint and commit**

```bash
rubocop lib/gempilot/cli/commands/new.rb spec/gempilot/cli/commands/new_namespace_spec.rb
git add lib/gempilot/cli/commands/new.rb spec/gempilot/cli/commands/new_namespace_spec.rb
git commit -m "Refactor new command onto GemConstant"
```

### Task B4: Refactor `destroy` to use `GemConstant`

**Files:**
- Modify: `lib/gempilot/cli/commands/destroy.rb`

- [ ] **Step 1: Run the destroy specs (baseline green)**

Run: `rspec spec/gempilot/cli/commands/destroy_namespace_spec.rb spec/gempilot/cli/commands/destroy_interactive_spec.rb`
Expected: PASS.

- [ ] **Step 2: Refactor `destroy.rb`**

In `lib/gempilot/cli/commands/destroy.rb`:

Replace `prompt_for_path`:

```ruby
        def prompt_for_path(type)
          ask(colors.green(type), required: true)
        end
```

Replace `dispatch_destroy`:

```ruby
        def dispatch_destroy(type, path)
          case type
          when "class"   then destroy_class(gem_constant(path))
          when "module"  then destroy_module(gem_constant(path))
          when "command" then destroy_command(path)
          else
            puts colors.red("Unknown type '#{type}'. Use class, module, or command.")
            exit 1
          end
        end
```

Delete `test_path_for`. Replace `destroy_class` and `destroy_module`:

```ruby
        def destroy_class(constant)
          lib_path = constant.lib_path
          test_path = constant.test_path(@test_framework)

          remove_file(lib_path)
          remove_file(test_path)
          cleanup_empty_dirs(lib_path, test_path)
        end

        def destroy_module(constant)
          lib_path = constant.lib_path

          remove_file(lib_path)
          remove_empty_parents(File.dirname(lib_path), File.join("lib", @require_path))
        end
```

Leave `destroy_command`, `cleanup_empty_dirs`, `remove_empty_parents`, `remove_file`, `print_remove`, and `print_skip` unchanged.

- [ ] **Step 3: Run destroy specs + minitest**

Run: `rspec spec/gempilot/cli/commands/destroy_namespace_spec.rb spec/gempilot/cli/commands/destroy_interactive_spec.rb`
Expected: PASS.

Run: `ruby -Itest -Ilib -e 'require File.expand_path("test/gempilot/cli/destroy_command_test.rb")'`
Expected: PASS, 0 failures.

- [ ] **Step 4: Lint and commit**

```bash
rubocop lib/gempilot/cli/commands/destroy.rb
git add lib/gempilot/cli/commands/destroy.rb
git commit -m "Refactor destroy command onto GemConstant"
```

### Task B5: Remove the now-dead `parse_constant` and `validate_gem_root!`

**Files:**
- Modify: `lib/gempilot/cli/gem_context.rb`

- [ ] **Step 1: Confirm they're unused**

Run: `grep -rn "parse_constant\|validate_gem_root" lib`
Expected: only the two definitions in `gem_context.rb` (no call sites remain after B3/B4).

- [ ] **Step 2: Delete both methods**

In `lib/gempilot/cli/gem_context.rb`, delete the entire `parse_constant` method and the entire `validate_gem_root!` method. Keep `using String::Inflectable` (still used by `detect_gem_context`'s `camelize`), `detect_gem_context`, and `gem_constant`.

- [ ] **Step 3: Run the full suite + minitest**

Run: `rspec`
Expected: PASS (whole RSpec suite).

Run: `ruby -Itest -Ilib -e 'Dir["test/**/*_test.rb"].each { |f| require File.expand_path(f) }'`
Expected: only the known environmental `create_command_test` bundler-subprocess failure (see memory `gempilot-test-running-env`); 0 other failures.

- [ ] **Step 4: Lint and commit**

```bash
rubocop lib/gempilot/cli/gem_context.rb
git add lib/gempilot/cli/gem_context.rb
git commit -m "Drop parse_constant/validate_gem_root! superseded by GemConstant"
```

---

## Part C — Robust test-framework detection

### Task C1: Detect rspec by its config files, not a bare `spec/` directory

**Files:**
- Modify: `lib/gempilot/cli/gem_context.rb`
- Test: `spec/gempilot/cli/commands/new_interactive_spec.rb`

- [ ] **Step 1: Add a spec proving a stray `spec/` dir doesn't force rspec**

In `spec/gempilot/cli/commands/new_interactive_spec.rb`, add inside `describe "interactive mode"`:

```ruby
    context "when a spec/ directory exists but there is no rspec config" do
      before { mkdir_p("spec") }

      it "still scaffolds a minitest test file" do
        generate("1\nServices::Auth\n")

        expect(File).to exist("test/my_gem/services/auth_test.rb")
      end
    end
```

- [ ] **Step 2: Run it, verify it fails**

Run: `rspec spec/gempilot/cli/commands/new_interactive_spec.rb -e "stray"` (or `-e "no rspec config"`)
Expected: FAIL — current `File.directory?("spec")` returns true, so an rspec spec file is generated under `spec/` and the expected `test/...` file does not exist.

- [ ] **Step 3: Replace the detection**

In `lib/gempilot/cli/gem_context.rb`, change the last line of `detect_gem_context` from:

```ruby
        @test_framework = File.directory?("spec") ? :rspec : :minitest
```
to:
```ruby
        @test_framework = detect_test_framework
```

Add this private method (next to `gem_constant`):

```ruby
      # Detect rspec by its canonical config files rather than the mere
      # presence of a spec/ directory, which a minitest project may also have.
      def detect_test_framework
        return :rspec if File.exist?(".rspec") || File.exist?(File.join("spec", "spec_helper.rb"))

        :minitest
      end
```

- [ ] **Step 4: Run the spec + full suite**

Run: `rspec spec/gempilot/cli/commands/new_interactive_spec.rb`
Expected: PASS.

Run: `rspec`
Expected: PASS (whole suite).

- [ ] **Step 5: Lint and commit**

```bash
rubocop lib/gempilot/cli/gem_context.rb spec/gempilot/cli/commands/new_interactive_spec.rb
git add lib/gempilot/cli/gem_context.rb spec/gempilot/cli/commands/new_interactive_spec.rb
git commit -m "Detect rspec by config files, not a bare spec/ dir"
```

---

## Part D — CLAUDE.md accuracy pass

### Task D1: Correct the stale architecture and feature notes

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Fix the version-tasks note**

In `CLAUDE.md`, under "Generated Gem Features", replace:

```
- Version management rake tasks in `rakelib/version.rake` (current, bump, commit, revert, release:full)
```
with:
```
- Version lifecycle rake tasks installed via `Gempilot::VersionTask.new` (a `Rake::TaskLib`): `version:current/bump/commit/tag/untag/reset/revert`, composite `version:release`/`version:unrelease`, and `version:github:release/unrelease/list`
```

- [ ] **Step 2: Fix the `exe/` note in the ISSUES section**

In `CLAUDE.md`, update issue 1 to reflect reality — `exe/gempilot` keeps a *conditional* `bundler/setup` (only when a sibling `Gemfile` exists), it was not removed. Replace the issue body with:

```
1. RESOLVED — `exe/gempilot` previously had an unconditional `ENV["BUNDLE_GEMFILE"]` + `require "bundler/setup"`, breaking `gem install` usage. It now guards both behind `if File.exist?(gemfile)` (the Ronin pattern), so installed gems skip Bundler while in-repo runs still use it.
```

- [ ] **Step 3: Note the constant model under Architecture**

In `CLAUDE.md`, under "Architecture", add a bullet:

```
- `GemConstant` value object (`lib/gempilot/gem_constant.rb`) owns constant→namespace/path resolution for `new`/`destroy`; constants are rooted at the gem module by construction
```

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "Refresh CLAUDE.md: version tasks, exe note, GemConstant"
```

---

## Final verification

- [ ] **Full RSpec suite**

Run: `rspec`
Expected: PASS (all examples, including the new `gem_constant_spec` and added cases).

- [ ] **Minitest suite**

Run: `ruby -Itest -Ilib -e 'Dir["test/**/*_test.rb"].each { |f| require File.expand_path(f) }'`
Expected: only the known environmental `create_command_test` bundler failure; 0 others.

- [ ] **RuboCop (real source dirs)**

Run: `rubocop lib spec test exe Rakefile`
Expected: no offenses.

- [ ] **Confirm net code reduction**

Run: `git diff --stat master -- lib/gempilot/cli/commands/new.rb lib/gempilot/cli/commands/destroy.rb lib/gempilot/cli/gem_context.rb`
Expected: `new.rb`/`destroy.rb`/`gem_context.rb` shrink (constant logic centralized in `gem_constant.rb`).

---

## Self-review notes (done while writing)

- **Spec coverage:** each critique maps to a task — duplication + bug class → B1–B5; `abort`/`raise` → A1; magic string → A2; fragile framework detection → C1; CLAUDE.md drift → D1. The `validate_gem_root!` leniency is resolved as a documented design decision in B1.
- **Type consistency:** `GemConstant#qualified/namespaces/name/lib_path/test_path(framework)` are used with the same names/signatures across B3/B4; the factory is `gem_constant(input)` everywhere.
- **Behavior change called out:** B3 makes non-interactive bare names root under the gem (previously rejected). No existing test asserted the rejection; B3 Step 1 adds a test documenting the new behavior.
