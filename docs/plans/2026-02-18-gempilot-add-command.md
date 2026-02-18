# `gempilot add` Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a `gempilot add <type> <path>` command that generates classes, modules, and commands inside existing gems with proper Zeitwerk-compliant file paths, module nesting, and test files.

**Architecture:** The `add` command detects the gem context (name, test framework) from the current directory, parses the user-provided path into namespace segments, generates the source file with properly nested `module`/`class` wrappers, and creates a matching test file. No ERB templates for class/module (nesting depth is variable) — content is built programmatically. The `command` type uses an ERB template since its structure is fixed.

**Tech Stack:** CommandKit (options, arguments, interactive, colors, inflector), Generator module (mkdir, print_action), ERB for command template, Minitest for tests.

---

## Key Design Decisions

**Why no ERB for class/module?** Nesting depth varies — `add class auth` is 1 level, `add class services/auth/token` is 3. Loops in ERB produce ugly templates. A Ruby method that builds the string is cleaner and testable.

**Why ERB for command?** Command boilerplate is fixed structure (always under `Gempilot::CLI::Commands`), so a template works well.

**Gem context detection:** Find `*.gemspec` in cwd. Extract gem name from filename. Detect test framework from `spec/` vs `test/` directory presence. No config file needed.

**Generator module reuse:** The `Add` command needs `mkdir` and `print_action` from Generator, but Generator requires `template_dir`. We'll set `template_dir` to `data/templates/add/` (for the command ERB) and add a `create_file(path, content)` helper to Generator for programmatic file creation.

---

### Task 0: Create swap space

This environment has limited memory. Create 4GB of swap before doing anything else.

**Step 1: Create and enable swap**

```bash
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

**Step 2: Verify**

```bash
free -h
```

Expected: Swap line shows ~4.0G total.

---

### Task 1: Add `create_file` helper to Generator

**Files:**
- Modify: `lib/gempilot/cli/generator.rb`
- Test: `test/gempilot/cli/generator_test.rb`

**Step 1: Write the failing test**

Add to `test/gempilot/cli/generator_test.rb`:

```ruby
def test_create_file_writes_content
  Dir.mktmpdir do |dir|
    Dir.chdir(dir) do
      path = "test_output.rb"
      content = "# hello\n"

      @generator.create_file(path, content)

      assert_path_exists path
      assert_equal content, File.read(path)
    end
  end
end
```

Note: Check the existing generator test file first to understand how `@generator` is set up. Adapt the test to match the existing pattern (it may use a test command class with `include Generator` and `template_dir` set). The key assertion is: `create_file` writes the content and the file exists.

**Step 2: Run test to verify it fails**

Run: `cd /workspace/gempilot/misc-updates && ruby -Ilib -Itest test/gempilot/cli/generator_test.rb`
Expected: FAIL — `NoMethodError: undefined method 'create_file'`

**Step 3: Write minimal implementation**

Add to `lib/gempilot/cli/generator.rb`, after the `touch` method:

```ruby
def create_file(path, content)
  print_action "create", path
  File.write(path, content)
end
```

**Step 4: Run test to verify it passes**

Run: `cd /workspace/gempilot/misc-updates && ruby -Ilib -Itest test/gempilot/cli/generator_test.rb`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/gempilot/cli/generator.rb test/gempilot/cli/generator_test.rb
git commit -m "feat(generator): add create_file helper for programmatic file creation"
```

---

### Task 2: Create the `add` command skeleton with gem context detection

**Files:**
- Create: `lib/gempilot/cli/commands/add.rb`
- Create: `test/gempilot/cli/add_command_test.rb`

**Step 1: Write the failing test**

Create `test/gempilot/cli/add_command_test.rb`:

```ruby
require "test_helper"
require "gempilot/cli"
require "tmpdir"
require "stringio"

module Gempilot
  class CLI
    class AddCommandTest < Minitest::Test
      def setup
        @tmpdir = Dir.mktmpdir("add_command_test")
        @original_dir = Dir.pwd

        # Create a minimal gem directory to simulate being inside a gem
        Dir.chdir(@tmpdir)
        FileUtils.mkdir_p("lib/my_gem")
        FileUtils.mkdir_p("test")
        File.write("my_gem.gemspec", 'Gem::Specification.new { |s| s.name = "my_gem" }')
      end

      def teardown
        Dir.chdir(@original_dir)
        FileUtils.rm_rf(@tmpdir)
      end

      def test_add_class_creates_lib_file
        run_add_command("class", "authentication")

        assert_path_exists "lib/my_gem/authentication.rb"
      end

      def test_add_class_creates_correct_module_nesting
        run_add_command("class", "authentication")

        content = File.read("lib/my_gem/authentication.rb")

        assert_includes content, "module MyGem"
        assert_includes content, "class Authentication"
      end

      private

      def run_add_command(type, path)
        stdout = StringIO.new
        command = Commands::Add.new(stdout: stdout)
        command.main([type, path])
      end
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `cd /workspace/gempilot/misc-updates && ruby -Ilib -Itest test/gempilot/cli/add_command_test.rb`
Expected: FAIL — `NameError: uninitialized constant Commands::Add`

**Step 3: Write minimal implementation**

Create `data/templates/add/` directory (empty for now — needed by Generator):
```bash
mkdir -p /workspace/gempilot/misc-updates/data/templates/add
touch /workspace/gempilot/misc-updates/data/templates/add/.keep
```

Create `lib/gempilot/cli/commands/add.rb`:

```ruby
require_relative "../command"
require_relative "../generator"
require "command_kit/inflector"

module Gempilot
  class CLI
    module Commands
      class Add < Command
        include Generator

        template_dir File.join(Gempilot::ROOT, "data", "templates", "add")

        usage "[options] TYPE PATH"
        description "Add a class, module, or command to an existing gem"

        examples [
          "class authentication",
          "class services/authentication",
          "module middleware",
          "command deploy"
        ]

        argument :type, required: true,
                        desc: "Type to generate (class, module, command)"

        argument :path, required: true,
                        desc: "Path relative to gem namespace (e.g., services/authentication)"

        def run(type = nil, path = nil)
          type = type || begin
            puts colors.bright_black("What kind of component do you want to add?")
            ask_multiple_choice(colors.green("Type"), %w[class module command])
          end

          path = path || begin
            puts
            puts colors.bright_black("Path relative to the gem namespace (e.g., services/authentication).")
            ask(colors.green("Path"), required: true)
          end

          detect_gem_context

          case type
          when "class"   then add_class(path)
          when "module"  then add_module(path)
          when "command" then add_command(path)
          else
            puts colors.red("Unknown type '#{type}'. Use class, module, or command.")
            exit 1
          end
        end

        private

        def detect_gem_context
          gemspec = Dir.glob("*.gemspec").first

          unless gemspec
            puts colors.red("No gemspec found in current directory. Run this from your gem's root.")
            exit 1
          end

          @gem_name = File.basename(gemspec, ".gemspec")
          @gem_module = CommandKit::Inflector.camelize(@gem_name)
          @test_framework = File.directory?("spec") ? :rspec : :minitest
        end

        def build_nested_source(namespaces, type_keyword, name)
          lines = []
          namespaces.each_with_index do |ns, i|
            lines << "#{"  " * i}module #{ns}"
          end

          depth = namespaces.length
          lines << "#{"  " * depth}#{type_keyword} #{name}"
          lines << "#{"  " * depth}end"

          namespaces.length.times do |i|
            lines << "#{"  " * (namespaces.length - 1 - i)}end"
          end

          lines.join("\n") + "\n"
        end

        def parse_path(path)
          segments = path.tr("-", "_").split("/")
          modules = segments[0...-1].map { |s| CommandKit::Inflector.camelize(s) }
          name = CommandKit::Inflector.camelize(segments.last)
          [segments, modules, name]
        end

        def add_class(path)
          segments, intermediate_modules, class_name = parse_path(path)
          namespaces = [@gem_module] + intermediate_modules
          file_path = File.join("lib", @gem_name, *segments) + ".rb"

          puts
          puts colors.bright_white("Adding class ") + colors.bold(colors.cyan("#{namespaces.join('::')}::#{class_name}")) + colors.bright_white("...")
          puts

          # Create directories
          dir = File.dirname(file_path)
          mkdir(dir) unless File.directory?(dir)

          # Create lib file
          source = "# frozen_string_literal: true\n\n" + build_nested_source(namespaces, "class", class_name)
          create_file(file_path, source)

          # Create test file
          add_test_file(namespaces, class_name, segments)
        end

        def add_module(path)
          segments, intermediate_modules, mod_name = parse_path(path)
          namespaces = [@gem_module] + intermediate_modules
          file_path = File.join("lib", @gem_name, *segments) + ".rb"

          puts
          puts colors.bright_white("Adding module ") + colors.bold(colors.cyan("#{namespaces.join('::')}::#{mod_name}")) + colors.bright_white("...")
          puts

          dir = File.dirname(file_path)
          mkdir(dir) unless File.directory?(dir)

          source = "# frozen_string_literal: true\n\n" + build_nested_source(namespaces, "module", mod_name)
          create_file(file_path, source)
        end

        def add_command(path)
          segments, _, command_name = parse_path(path)
          file_path = File.join("lib", @gem_name, "cli", "commands", segments.last + ".rb")

          puts
          puts colors.bright_white("Adding command ") + colors.bold(colors.cyan(command_name)) + colors.bright_white("...")
          puts

          dir = File.dirname(file_path)
          mkdir(dir) unless File.directory?(dir)

          @command_name = command_name
          @command_file_name = segments.last
          erb "command.rb.erb", file_path
        end

        def add_test_file(namespaces, class_name, segments)
          if @test_framework == :rspec
            test_path = File.join("spec", @gem_name, *segments) + "_spec.rb"
            test_dir = File.dirname(test_path)
            mkdir(test_dir) unless File.directory?(test_dir)

            content = <<~RUBY
              # frozen_string_literal: true

              require "spec_helper"

              RSpec.describe #{namespaces.join('::')}::#{class_name} do
                pending "add some examples"
              end
            RUBY
            create_file(test_path, content)
          else
            test_path = File.join("test", @gem_name, *segments) + "_test.rb"
            test_dir = File.dirname(test_path)
            mkdir(test_dir) unless File.directory?(test_dir)

            content = <<~RUBY
              # frozen_string_literal: true

              require "test_helper"

              module #{namespaces.first}
                class #{(namespaces[1..] + [class_name]).join('::')}Test < Minitest::Test
                  def test_placeholder
                    assert true
                  end
                end
              end
            RUBY
            create_file(test_path, content)
          end
        end
      end
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `cd /workspace/gempilot/misc-updates && ruby -Ilib -Itest test/gempilot/cli/add_command_test.rb`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/gempilot/cli/commands/add.rb test/gempilot/cli/add_command_test.rb data/templates/add/.keep
git commit -m "feat: add 'gempilot add' command with class generation"
```

---

### Task 3: Add tests for nested paths and module nesting

**Files:**
- Modify: `test/gempilot/cli/add_command_test.rb`

**Step 1: Write the failing tests**

Add to the test class:

```ruby
def test_add_class_with_nested_path_creates_directories
  run_add_command("class", "services/authentication")

  assert File.directory?("lib/my_gem/services")
  assert_path_exists "lib/my_gem/services/authentication.rb"
end

def test_add_class_with_nested_path_has_correct_nesting
  run_add_command("class", "services/authentication")

  content = File.read("lib/my_gem/services/authentication.rb")

  assert_includes content, "module MyGem"
  assert_includes content, "module Services"
  assert_includes content, "class Authentication"
end

def test_add_class_with_deeply_nested_path
  run_add_command("class", "services/auth/token_validator")

  content = File.read("lib/my_gem/services/auth/token_validator.rb")

  assert_includes content, "module MyGem"
  assert_includes content, "module Services"
  assert_includes content, "module Auth"
  assert_includes content, "class TokenValidator"
end

def test_add_class_creates_frozen_string_literal
  run_add_command("class", "authentication")

  content = File.read("lib/my_gem/authentication.rb")

  assert content.start_with?("# frozen_string_literal: true")
end
```

**Step 2: Run tests to verify they pass**

Run: `cd /workspace/gempilot/misc-updates && ruby -Ilib -Itest test/gempilot/cli/add_command_test.rb`
Expected: PASS (implementation from Task 2 should handle these)

If any fail, fix the implementation and re-run.

**Step 3: Commit**

```bash
git add test/gempilot/cli/add_command_test.rb
git commit -m "test: add nested path tests for gempilot add class"
```

---

### Task 4: Add tests for test file generation

**Files:**
- Modify: `test/gempilot/cli/add_command_test.rb`

**Step 1: Write the failing tests**

```ruby
def test_add_class_creates_minitest_file
  run_add_command("class", "authentication")

  assert_path_exists "test/my_gem/authentication_test.rb"

  content = File.read("test/my_gem/authentication_test.rb")

  assert_includes content, "require \"test_helper\""
  assert_includes content, "module MyGem"
  assert_includes content, "Minitest::Test"
end

def test_add_class_creates_rspec_file_when_spec_dir_exists
  # Switch to rspec by creating spec/ and removing test/
  FileUtils.rm_rf("test")
  FileUtils.mkdir_p("spec")

  run_add_command("class", "authentication")

  assert_path_exists "spec/my_gem/authentication_spec.rb"

  content = File.read("spec/my_gem/authentication_spec.rb")

  assert_includes content, "require \"spec_helper\""
  assert_includes content, "RSpec.describe MyGem::Authentication"
end

def test_add_class_creates_nested_test_file
  run_add_command("class", "services/authentication")

  assert_path_exists "test/my_gem/services/authentication_test.rb"
end
```

**Step 2: Run tests**

Run: `cd /workspace/gempilot/misc-updates && ruby -Ilib -Itest test/gempilot/cli/add_command_test.rb`
Expected: PASS

**Step 3: Commit**

```bash
git add test/gempilot/cli/add_command_test.rb
git commit -m "test: add test file generation tests for gempilot add"
```

---

### Task 5: Add module generation and tests

**Files:**
- Modify: `test/gempilot/cli/add_command_test.rb`

**Step 1: Write the failing tests**

```ruby
def test_add_module_creates_lib_file
  run_add_command("module", "middleware")

  assert_path_exists "lib/my_gem/middleware.rb"

  content = File.read("lib/my_gem/middleware.rb")

  assert_includes content, "module MyGem"
  assert_includes content, "module Middleware"
  refute_includes content, "class"
end

def test_add_module_does_not_create_test_file
  run_add_command("module", "middleware")

  refute_path_exists "test/my_gem/middleware_test.rb"
end

def test_add_module_with_nested_path
  run_add_command("module", "services/concerns")

  content = File.read("lib/my_gem/services/concerns.rb")

  assert_includes content, "module MyGem"
  assert_includes content, "module Services"
  assert_includes content, "module Concerns"
end
```

**Step 2: Run tests**

Run: `cd /workspace/gempilot/misc-updates && ruby -Ilib -Itest test/gempilot/cli/add_command_test.rb`
Expected: PASS (implementation from Task 2 covers modules)

**Step 3: Commit**

```bash
git add test/gempilot/cli/add_command_test.rb
git commit -m "test: add module generation tests for gempilot add"
```

---

### Task 6: Add command generation with ERB template

**Files:**
- Create: `data/templates/add/command.rb.erb`
- Modify: `test/gempilot/cli/add_command_test.rb`

**Step 1: Write the failing test**

```ruby
def test_add_command_creates_command_file
  # Need cli/commands directory to exist (simulates a CLI gem)
  FileUtils.mkdir_p("lib/my_gem/cli/commands")

  run_add_command("command", "deploy")

  assert_path_exists "lib/my_gem/cli/commands/deploy.rb"

  content = File.read("lib/my_gem/cli/commands/deploy.rb")

  assert_includes content, "class Deploy < Command"
  assert_includes content, "module MyGem"
  assert_includes content, "module Commands"
  assert_includes content, 'description'
end
```

**Step 2: Run test to verify it fails**

Run: `cd /workspace/gempilot/misc-updates && ruby -Ilib -Itest test/gempilot/cli/add_command_test.rb`
Expected: FAIL — template file missing, `Errno::ENOENT`

**Step 3: Create the ERB template**

Create `data/templates/add/command.rb.erb`:

```erb
# frozen_string_literal: true

require_relative "../command"

module <%= @gem_module %>
  class CLI
    module Commands
      class <%= @command_name %> < Command
        usage "[options]"
        description "TODO: describe the <%= @command_file_name %> command"

        def run
        end
      end
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `cd /workspace/gempilot/misc-updates && ruby -Ilib -Itest test/gempilot/cli/add_command_test.rb`
Expected: PASS

**Step 5: Commit**

```bash
git add data/templates/add/command.rb.erb test/gempilot/cli/add_command_test.rb
git commit -m "feat: add command generation with ERB template"
```

---

### Task 7: Add error handling test

**Files:**
- Modify: `test/gempilot/cli/add_command_test.rb`

**Step 1: Write the failing test**

```ruby
def test_add_fails_without_gemspec
  # Remove gemspec
  FileUtils.rm("my_gem.gemspec")

  stdout = StringIO.new
  command = Commands::Add.new(stdout: stdout)

  assert_raises(SystemExit) do
    command.main(["class", "foo"])
  end
end

def test_add_fails_with_unknown_type
  stdout = StringIO.new
  command = Commands::Add.new(stdout: stdout)

  assert_raises(SystemExit) do
    command.main(["widget", "foo"])
  end
end
```

**Step 2: Run tests**

Run: `cd /workspace/gempilot/misc-updates && ruby -Ilib -Itest test/gempilot/cli/add_command_test.rb`
Expected: PASS

**Step 3: Commit**

```bash
git add test/gempilot/cli/add_command_test.rb
git commit -m "test: add error handling tests for gempilot add"
```

---

### Task 8: Run full test suite and verify

**Step 1: Run all tests**

Run: `cd /workspace/gempilot/misc-updates && ruby -Ilib -Itest -e 'Dir.glob("test/**/*_test.rb").each { |f| require_relative f }'`
Expected: All tests pass (30 existing + new add command tests)

**Step 2: Manual smoke test**

```bash
cd /tmp
ruby -I/workspace/gempilot/misc-updates/lib -e 'require "gempilot/cli"; Gempilot::CLI.start' -- new smoke_test --test minitest --no-exe --no-git --author Test --email t@t.com --summary Test --ruby-version 3.4.8
cd smoke_test
ruby -I/workspace/gempilot/misc-updates/lib -e 'require "gempilot/cli"; Gempilot::CLI.start' -- add class services/authentication
ruby -I/workspace/gempilot/misc-updates/lib -e 'require "gempilot/cli"; Gempilot::CLI.start' -- add module middleware
cat lib/smoke_test/services/authentication.rb
cat lib/smoke_test/middleware.rb
cat test/smoke_test/services/authentication_test.rb
```

Expected output for `lib/smoke_test/services/authentication.rb`:
```ruby
# frozen_string_literal: true

module SmokeTest
  module Services
    class Authentication
    end
  end
end
```

**Step 3: Commit (if any fixes needed)**

```bash
git add -A
git commit -m "fix: address issues found in smoke test"
```

---

## Summary of files

| File | Action |
|------|--------|
| `lib/gempilot/cli/generator.rb` | Add `create_file` method |
| `lib/gempilot/cli/commands/add.rb` | Create — the Add command |
| `data/templates/add/command.rb.erb` | Create — ERB template for command type |
| `data/templates/add/.keep` | Create — keeps directory in git |
| `test/gempilot/cli/add_command_test.rb` | Create — comprehensive tests |
| `test/gempilot/cli/generator_test.rb` | Modify — test for `create_file` |
