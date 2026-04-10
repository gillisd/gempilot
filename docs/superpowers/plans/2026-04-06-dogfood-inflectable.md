# Dogfood String::Inflectable Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `CommandKit::Inflector` with gempilot's own `String::Inflectable` refinement, and wire the template generator to copy all version management domain objects into generated gems.

**Architecture:** Create `String::InflectionMethods` (class methods) and `String::Inflectable` (refinement) under `lib/core_ext/`. Switch all 6 call sites from `CommandKit::Inflector.camelize/underscore` to the refinement. Copy the same files into the template directory. Update `gem_builder.rb` to copy all rakelib support files + core_ext into generated gems. Rewrite `version.rake.erb` as thin domain-object wiring.

**Tech Stack:** Ruby refinements, Zeitwerk, ERB templates

---

## File Structure

### New in gempilot
| Path | Responsibility |
|------|----------------|
| `lib/core_ext/string/inflection_methods.rb` | `dasherize`, `underscore`, `camelize` as module methods |
| `lib/core_ext/string/refinements/inflectable.rb` | Refinement wrapping InflectionMethods onto String |

### New in templates
| Path | Responsibility |
|------|----------------|
| `data/templates/gem/lib/core_ext/string/inflection_methods.rb` | Same — shipped to generated gems |
| `data/templates/gem/lib/core_ext/string/refinements/inflectable.rb` | Same — shipped to generated gems |
| `data/templates/gem/rakelib/project.rb` | Project introspection for generated gems |

### Modify
| Path | Change |
|------|--------|
| `lib/gempilot.rb:7` | Add `LOADER.ignore` for core_ext |
| `rakelib/project.rb:1-3,36` | Switch to refinement |
| `lib/gempilot/cli/gem_context.rb:1,19,27` | Switch to refinement |
| `lib/gempilot/cli/commands/create.rb:4,102` | Switch to refinement |
| `lib/gempilot/cli/commands/new.rb:4,120-121` | Switch to refinement |
| `lib/gempilot/cli/commands/destroy.rb:3,95` | Switch to refinement |
| `lib/gempilot/cli/gem_builder.rb:49-52` | Copy all rakelib + core_ext files |
| `data/templates/gem/rakelib/version.rake.erb` | Rewrite to use domain objects |
| `data/templates/gem/lib/gem_name.rb.erb:9` | Add `LOADER.ignore` for core_ext |
| `data/templates/gem/Gemfile.erb` | Add `warning` gem |

---

### Task 1: Create inflection files in gempilot

**Files:**
- Create: `lib/core_ext/string/inflection_methods.rb`
- Create: `lib/core_ext/string/refinements/inflectable.rb`
- Modify: `lib/gempilot.rb`

- [ ] **Step 1: Create `lib/core_ext/string/inflection_methods.rb`**

```ruby
require "strscan"

module String::InflectionMethods
  def dasherize(name) = name.to_s.tr("_", "-")

  def underscore(name)
    scanner    = StringScanner.new(name.to_s)
    new_string = String.new
    until scanner.eos?
      if (separator = scanner.scan(/[_-]+/))
        new_string << ("_" * separator.length)
      else
        if (capitalized = scanner.scan(/[A-Z][a-z\d]+/))
          new_string << capitalized
        elsif (uppercase = scanner.scan(/[A-Z][A-Z\d]*(?=[A-Z_-]|$)/))
          new_string << uppercase
        elsif (lowercase = scanner.scan(/[a-z][a-z\d]*/))
          new_string << lowercase
        else
          raise(ArgumentError, "cannot convert string to underscored: #{scanner.string.inspect}")
        end
        if (separator = scanner.scan(/[_-]+/))
          new_string << ("_" * separator.length)
        elsif !scanner.eos?
          new_string << "_"
        end
      end
    end
    new_string.downcase!
    new_string
  end

  def camelize(name)
    scanner = StringScanner.new(name.to_s)
    new_string = String.new
    until scanner.eos?
      if (word = scanner.scan(/[A-Za-z\d]+/))
        word.capitalize!
        new_string << word
      elsif (numbers = scanner.scan(/[_-]\d+/))
        new_string << "_#{numbers[1..]}"
      elsif scanner.scan(/[_-]+/)
      elsif scanner.scan(%r{/})
        new_string << "::"
      else
        raise(ArgumentError, "cannot convert string to CamelCase: #{scanner.string.inspect}")
      end
    end
    new_string
  end
end
```

- [ ] **Step 2: Create `lib/core_ext/string/refinements/inflectable.rb`**

```ruby
require_relative "../inflection_methods"

module String::Inflectable
  refine String.singleton_class do
    import_methods String::InflectionMethods
  end

  refine String do
    def dasherize
      self.class.dasherize(self)
    end

    def underscore
      self.class.underscore(self)
    end

    def camelize
      self.class.camelize(self)
    end
  end
end
```

- [ ] **Step 3: Add `LOADER.ignore` in `lib/gempilot.rb`**

In `lib/gempilot.rb`, add the ignore line after `LOADER = Zeitwerk::Loader.for_gem`:

```ruby
module Gempilot
  LOADER = Zeitwerk::Loader.for_gem
  LOADER.inflector.inflect("cli" => "CLI")
  LOADER.ignore("#{__dir__}/core_ext")
  LOADER.setup
```

- [ ] **Step 4: Verify the refinement works**

Run: `ruby -e 'require_relative "lib/core_ext/string/refinements/inflectable"; using String::Inflectable; puts "my_gem".camelize'`
Expected: `MyGem`

- [ ] **Step 5: Verify Zeitwerk still loads cleanly**

Run: `bundle exec ruby -e 'require "gempilot"; Gempilot::LOADER.eager_load(force: true); puts "OK"'`
Expected: `OK`

- [ ] **Step 6: Commit**

```bash
git add lib/core_ext/ lib/gempilot.rb
git commit -m "Add String::Inflectable refinement for inflection"
```

---

### Task 2: Switch gempilot from CommandKit::Inflector to String::Inflectable

**Files:**
- Modify: `rakelib/project.rb`
- Modify: `lib/gempilot/cli/gem_context.rb`
- Modify: `lib/gempilot/cli/commands/create.rb`
- Modify: `lib/gempilot/cli/commands/new.rb`
- Modify: `lib/gempilot/cli/commands/destroy.rb`

- [ ] **Step 1: Switch `rakelib/project.rb`**

Replace line 3 (`require "command_kit/inflector"`) with:
```ruby
require_relative "../lib/core_ext/string/refinements/inflectable"
```

Add `using String::Inflectable` inside the class body (after `class Project`).

Replace line 36 (`Object.const_get(CommandKit::Inflector.camelize(name))`) with:
```ruby
Object.const_get(name.camelize)
```

- [ ] **Step 2: Switch `lib/gempilot/cli/gem_context.rb`**

Replace line 1 (`require "command_kit/inflector"`) with:
```ruby
require_relative "../../core_ext/string/refinements/inflectable"
```

Add `using String::Inflectable` as the first line inside `module GemContext`.

Replace line 19 (`CommandKit::Inflector.camelize(@require_path)`) with:
```ruby
@require_path.camelize
```

Replace line 27 (`CommandKit::Inflector.underscore(p)`) with:
```ruby
p.underscore
```

- [ ] **Step 3: Switch `lib/gempilot/cli/commands/create.rb`**

Replace line 4 (`require "command_kit/inflector"`) with:
```ruby
require_relative "../../../core_ext/string/refinements/inflectable"
```

Add `using String::Inflectable` inside the `Create` class body.

Replace line 102 (`CommandKit::Inflector.camelize(@require_path)`) with:
```ruby
@require_path.camelize
```

- [ ] **Step 4: Switch `lib/gempilot/cli/commands/new.rb`**

Replace line 4 (`require "command_kit/inflector"`) with:
```ruby
require_relative "../../../core_ext/string/refinements/inflectable"
```

Add `using String::Inflectable` inside the `New` class body.

Replace line 120 (`CommandKit::Inflector.underscore(name)`) with:
```ruby
name.underscore
```

Replace line 121 (`CommandKit::Inflector.camelize(name)`) with:
```ruby
name.camelize
```

- [ ] **Step 5: Switch `lib/gempilot/cli/commands/destroy.rb`**

Replace line 3 (`require "command_kit/inflector"`) with:
```ruby
require_relative "../../../core_ext/string/refinements/inflectable"
```

Add `using String::Inflectable` inside the `Destroy` class body.

Replace line 95 (`CommandKit::Inflector.underscore(name)`) with:
```ruby
name.underscore
```

- [ ] **Step 6: Run full test suite**

Run: `bundle exec rake test spec`
Expected: All pass

- [ ] **Step 7: Run rubocop**

Run: `bundle exec rubocop`
Expected: No offenses

- [ ] **Step 8: Commit**

```bash
git add rakelib/project.rb lib/gempilot/cli/gem_context.rb lib/gempilot/cli/commands/create.rb lib/gempilot/cli/commands/new.rb lib/gempilot/cli/commands/destroy.rb
git commit -m "Switch from CommandKit::Inflector to String::Inflectable"
```

---

### Task 3: Add inflection + project templates for generated gems

**Files:**
- Create: `data/templates/gem/lib/core_ext/string/inflection_methods.rb`
- Create: `data/templates/gem/lib/core_ext/string/refinements/inflectable.rb`
- Create: `data/templates/gem/rakelib/project.rb`

- [ ] **Step 1: Copy inflection files to template directory**

```bash
mkdir -p data/templates/gem/lib/core_ext/string/refinements
cp lib/core_ext/string/inflection_methods.rb data/templates/gem/lib/core_ext/string/inflection_methods.rb
cp lib/core_ext/string/refinements/inflectable.rb data/templates/gem/lib/core_ext/string/refinements/inflectable.rb
```

- [ ] **Step 2: Create `data/templates/gem/rakelib/project.rb`**

This is gempilot's own `rakelib/project.rb` but with the require path adjusted (rakelib is at gem root, so `../lib/` is correct — same as gempilot's own path):

```ruby
require "pathname"
require "warning"
require_relative "../lib/core_ext/string/refinements/inflectable"
require_relative "project_version"

# Introspects a gem project directory to discover its name, module,
# and version. Used by rake tasks to drive version lifecycle operations.
class Project
  class ProjectIntrospectionError < StandardError; end

  REDEFINITION_WARNING = /previous definition of VERSION was here/
  REINITIALIZATION_WARNING = /already initialized constant [^\s]+::VERSION/
  private_constant :REDEFINITION_WARNING, :REINITIALIZATION_WARNING

  using String::Inflectable

  attr_reader :root

  def initialize(root = __dir__)
    @root = Pathname(root)
    @verifications = Set.new
  end

  def lib
    root.join("lib")
        .tap { verify_existence! it }
  end

  def lib_project
    @lib_project ||= fetch_lib_project
  end

  def name
    lib_project.basename.to_s
  end

  def klass
    Object.const_get(name.camelize)
  end

  def version
    @version ||= fetch_version
  end

  def refresh_version!
    @version = fetch_version
  end

  def increment_version
    version.next_version
  end

  def version_tag = version.tag

  def version_value = version.value

  def write_version!(old_version, new_version)
    with_version_file do |f|
      source = f.read

      unless source.match?(Regexp.escape(old_version.value))
        abort "Expected to find #{old_version.value} in #{f.path} but did not"
      end

      f.rewind
      f.write source.gsub(old_version.value, new_version.value)
    end
  end

  private

  def with_version_file
    version.path.open(File::RDWR, 0o644) do |f|
      f.flock File::LOCK_EX
      yield f
      f.truncate(f.pos)
    end
  end

  def fetch_lib_project
    files = lib.glob("*.rb")
    dirs = files.map { it.sub_ext("") }.select(&:directory?)
    case dirs.count
    in 0 then raise ProjectIntrospectionError, "Could not identify project dir"
    in (2..)
      msg = "Found more than one possible project name:\n  - #{dirs.join("\n  - ")}"
      raise ProjectIntrospectionError, msg
    in 1 then dirs.first
    end
  end

  def fetch_version
    Warning.ignore(REDEFINITION_WARNING)
    Warning.ignore(REINITIALIZATION_WARNING)
    path = lib_project
           .join("version.rb")
           .tap { verify_existence! it }
           .tap { load it }

    value = klass.const_get(:VERSION)

    Version.new(path:, value:)
  end

  def verify_existence!(path)
    return true if @verifications.member? path

    raise ProjectIntrospectionError, "Expected #{path} to exist but does not" unless path.exist?

    @verifications.add path
  end
end
```

- [ ] **Step 3: Commit**

```bash
git add data/templates/gem/lib/core_ext/ data/templates/gem/rakelib/project.rb
git commit -m "Add inflection and Project templates for generated gems"
```

---

### Task 4: Rewrite version.rake.erb to use domain objects

**Files:**
- Rewrite: `data/templates/gem/rakelib/version.rake.erb`

- [ ] **Step 1: Rewrite `data/templates/gem/rakelib/version.rake.erb`**

Replace the entire file with:

```ruby
require_relative "project"
require_relative "version_tag"
require_relative "github_release"

root_path = File.expand_path("../", __dir__)
project = Project.new(root_path)

namespace :version do
  desc "Display the current version"
  task(:current) { puts "Current version: #{project.version_value}" }

  desc "Bump the patch version"
  task :bump do
    old_version = project.version
    new_version = project.increment_version
    project.write_version!(old_version, new_version)
    project.refresh_version!
    puts "Version bumped from #{old_version.value} to #{project.version_value}"
  end

  desc "Commit the version change"
  task(:commit) { VersionTag.new(project.version).create }

  desc "Tag the current version"
  task(:tag) { VersionTag.new(project.version).tag }

  desc "Untag the current version"
  task(:untag) { VersionTag.new(project.version).untag }

  desc "Reset the last version bump commit"
  task :reset do
    VersionTag.new(project.version).reset
    project.refresh_version!
  end

  desc "Revert the last version bump commit"
  task :revert do
    VersionTag.new(project.version).revert
    project.refresh_version!
  end

  desc "Bump version, commit, and tag"
  task release: ["version:bump", "version:commit", "version:tag"]

  desc "Untag and reset version"
  task unrelease: ["version:untag", "version:reset"]

  namespace :github do
    desc "Create a GitHub release for the current version"
    task(:release) { GithubRelease.new(project.version_tag).create }

    desc "Delete the GitHub release for the current version"
    task(:unrelease) { GithubRelease.new(project.version_tag).destroy }

    desc "List GitHub releases"
    task(:list) { GithubRelease.new(project.version_tag).list }
  end
end
```

Note: This file no longer needs ERB — it has zero interpolations. Rename it from `.erb` to plain `.rake` if desired, but the generator's `erb` method handles non-ERB content fine (ERB passes through plain text unchanged). Keeping the `.erb` extension avoids changing the `erb` call in `gem_builder.rb`.

- [ ] **Step 2: Commit**

```bash
git add data/templates/gem/rakelib/version.rake.erb
git commit -m "Rewrite version.rake.erb to use domain objects"
```

---

### Task 5: Update gem_builder.rb to copy all support files

**Files:**
- Modify: `lib/gempilot/cli/gem_builder.rb:49-52`

- [ ] **Step 1: Expand `render_version_rake` and add `render_core_ext`**

Replace the `render_version_rake` method (lines 49-52) with:

```ruby
      def render_version_rake
        mkdir "#{@gem_name}/rakelib"
        erb "rakelib/version.rake.erb", "#{@gem_name}/rakelib/version.rake"
        cp "rakelib/project.rb",         "#{@gem_name}/rakelib/project.rb"
        cp "rakelib/project_version.rb", "#{@gem_name}/rakelib/project_version.rb"
        cp "rakelib/version_tag.rb",     "#{@gem_name}/rakelib/version_tag.rb"
        cp "rakelib/github_release.rb",  "#{@gem_name}/rakelib/github_release.rb"
        cp "rakelib/strict_shell.rb",    "#{@gem_name}/rakelib/strict_shell.rb"
      end
```

Add a new method and call it from `render_core_templates` (add the call after line 46, `render_version_rake`):

```ruby
      def render_core_ext
        mkdir "#{@gem_name}/lib/core_ext"
        mkdir "#{@gem_name}/lib/core_ext/string"
        mkdir "#{@gem_name}/lib/core_ext/string/refinements"
        cp "lib/core_ext/string/inflection_methods.rb",
           "#{@gem_name}/lib/core_ext/string/inflection_methods.rb"
        cp "lib/core_ext/string/refinements/inflectable.rb",
           "#{@gem_name}/lib/core_ext/string/refinements/inflectable.rb"
      end
```

Add the call in `render_core_templates` after `render_version_rake`:

```ruby
        render_version_rake
        render_core_ext
```

- [ ] **Step 2: Run tests**

Run: `bundle exec rake test spec`
Expected: All pass

- [ ] **Step 3: Commit**

```bash
git add lib/gempilot/cli/gem_builder.rb
git commit -m "Wire generator to copy rakelib support files and core_ext"
```

---

### Task 6: Update generated gem Zeitwerk config and Gemfile

**Files:**
- Modify: `data/templates/gem/lib/gem_name.rb.erb`
- Modify: `data/templates/gem/Gemfile.erb`

- [ ] **Step 1: Add `LOADER.ignore` to `data/templates/gem/lib/gem_name.rb.erb`**

Change the non-hyphenated branch from:
```erb
module <%= @module_name %>
  LOADER = Zeitwerk::Loader.for_gem
  LOADER.setup
```

To:
```erb
module <%= @module_name %>
  LOADER = Zeitwerk::Loader.for_gem
  LOADER.ignore("#{__dir__}/core_ext")
  LOADER.setup
```

- [ ] **Step 2: Add `warning` gem to `data/templates/gem/Gemfile.erb`**

Add `gem "warning"` after the rubocop gems (before the closing of the file). Insert after the last `<% end -%>` on line 22:

```erb
<% if @test_framework == :rspec -%>
gem "rubocop-rspec"
<% end -%>
gem "warning"
```

- [ ] **Step 3: Commit**

```bash
git add data/templates/gem/lib/gem_name.rb.erb data/templates/gem/Gemfile.erb
git commit -m "Add Zeitwerk core_ext ignore and warning gem to generated gems"
```

---

### Task 7: Integration test

- [ ] **Step 1: Generate a test gem**

```bash
cd /var/tmp
bundle exec ruby -I /workspace/gempilot/lib /workspace/gempilot/exe/gempilot create test_gem --test minitest --no-exe --no-git --summary "Test" --author "Test" --email "test@test.com"
```

- [ ] **Step 2: Verify generated files exist**

```bash
ls test_gem/rakelib/
```

Expected: `github_release.rb  project.rb  project_version.rb  strict_shell.rb  version.rake  version_tag.rb`

```bash
ls test_gem/lib/core_ext/string/refinements/
```

Expected: `inflectable.rb`

- [ ] **Step 3: Verify rake tasks work**

```bash
cd test_gem && bundle install && bundle exec rake -T version
```

Expected: Lists 12 version tasks

```bash
bundle exec rake version:current
```

Expected: `Current version: 0.1.0`

- [ ] **Step 4: Verify full suite passes**

```bash
bundle exec rake
```

Expected: Tests + rubocop pass

- [ ] **Step 5: Clean up**

```bash
cd /workspace/gempilot
rm -rf /var/tmp/test_gem
```

- [ ] **Step 6: Run gempilot's own full suite**

Run: `bundle exec rake test spec`
Expected: All pass

Run: `bundle exec rubocop`
Expected: No offenses

- [ ] **Step 7: Commit any fixes needed**

```bash
git add -A && git commit -m "Fix integration issues" # only if fixes were needed
```
