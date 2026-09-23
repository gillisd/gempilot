# Zeitwerk Task Inflector Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `rake zeitwerk:validate` / `zeitwerk:all` (and the version tasks that share the same `Project` introspection) work for gems whose loader inflects the module name (`ECS`, not `Ecs`), by letting Zeitwerk itself say which loader manages the gem instead of guessing a constant name; and bring the `ZeitwerkTask` documentation (and, for consistency, every doc block under `lib/`) to rdoc's canonical form.

**Architecture:** Three cooperating changes. (1) A new `Gempilot::ProjectLoader` value object finds, in Zeitwerk's loader registry, the loader whose root directories include the project's autoload root — no constant name involved, so the gem's own `inflector.inflect` rules stay in charge. (2) `ZeitwerkTask`'s child scripts require the gem, then use `ProjectLoader` for `eager_load(force: true)` and `all_expected_cpaths`. (3) `Project` stops deriving a module name at all: it reads `VERSION` by `load`ing `version.rb` under an anonymous module and walking that private module tree, which also removes the constant-redefinition warnings `refresh_version!` used to trigger, so the `warning` runtime dependency goes away. `Project#module_name` / `#klass` are deleted (they were camelize guesses and are exactly the bug).

**Tech Stack:** Ruby 4.0, Zeitwerk 2.8 (`Zeitwerk::Registry.loaders`, `Loader#dirs`, `Loader#eager_load(force:)`, `Loader#all_expected_cpaths`, `Loader#cpath_expected_at`), Rake `TaskLib`, RSpec (`spec/`), RuboCop with rubocop-claude.

**Issue:** `93D7E88E-B6EB-11F1-8AF9-FE6CB9572C2E` — "Problems with zeitwerk_task.rb" (1. documentation formatting, 2. broken for inflected namespaces; no regexes).

## Global Constraints

- Ruby `>= 4.0`; `it` block parameter is used throughout; `Data.define` and `load(path, Module)` (Ruby 3.1+) are fine.
- No regex-based parsing of the user's loader file or inflections anywhere in this plan (issue requirement). The only regex-free way to learn the real namespace is to ask the loader Zeitwerk registered when the gem was required.
- Double-quoted strings (`Style/StringLiterals: double_quotes`); NO `# frozen_string_literal:` comments; trailing commas in multiline literals/arguments.
- rdoc doc blocks in the canonical form: a bare `##` line, then `# ...` lines, no blank line before the definition. Never put a line that reads like Ruby code inside a comment (`Claude/NoCommentedCode`, `MinLines: 1`, flags `require "..."`, assignments, bare identifiers): show usage in prose with `<tt>...</tt>`. Never use `TODO`/`NOTE` without attribution (`Claude/TaggedComments`). Regexes longer than a few characters in specs must be short or named (`Claude/MysteryRegex`).
- Zeitwerk: new file `lib/gempilot/project_loader.rb` MUST define `Gempilot::ProjectLoader` (`spec/zeitwerk_spec.rb` eager-loads gempilot).
- Verification: `bundle exec rspec <files>` for focused runs, `bundle exec rubocop <files>` per task, `bundle exec rake default` (= `test` + `spec` + `rubocop`) for the full gate.
- Baseline (verified 2026-09-23): RSpec `192 examples, 0 failures`; RuboCop `no offenses` on `lib`, `spec`, `test`; minitest `109 runs, 4 failures` — those 4 are the Gemfile-template ordering regression fixed by Task 1 of `docs/superpowers/plans/2026-09-23-land-betterleaks-jruby.md`. Apply that task first (one-line template change) to get a fully green gate; otherwise expect exactly those 4 create-command failures throughout.
- Commit messages: plain imperative sentences, no conventional-commit prefixes (repo style: "Own the Zeitwerk rake tasks; use tap(&:setup) loader form").

---

### Task 1: `Gempilot::ProjectLoader`

**Files:**
- Create: `lib/gempilot/project_loader.rb`
- Test: `spec/gempilot/project_loader_spec.rb`

**Interfaces:**
- Consumes: `Gempilot::Error` (defined in `lib/gempilot.rb`), `Zeitwerk::Registry.loaders` (a `Zeitwerk::Registry::Loaders` with `#each`; the same collection `Zeitwerk::Loader.eager_load_all` broadcasts over), `Zeitwerk::Loader#dirs`, `#unregister`.
- Produces: `Gempilot::ProjectLoader.new(root_dir) -> ProjectLoader` (`root_dir` is any path; stored as `File.realpath`), `#root_dir -> String`, `#loader -> Zeitwerk::Loader` raising `Gempilot::ProjectLoader::NotFound` (a `Gempilot::Error`) when no registered loader manages the directory. Task 3 relies on exactly `ProjectLoader.new(path).loader`.

- [ ] **Step 1: Write the failing spec**

Create `spec/gempilot/project_loader_spec.rb`:

```ruby
require "spec_helper"

RSpec.describe Gempilot::ProjectLoader do
  around do |example|
    Dir.mktmpdir("project_loader_spec") { |dir| Dir.chdir(dir) { example.run } }
  end

  def register_loader(dir)
    FileUtils.mkdir_p(dir)
    Zeitwerk::Loader.new.tap do |loader|
      loader.push_dir(dir)
      yield loader if block_given?
      loader.setup
    end
  end

  describe "#loader" do
    let!(:loader) { register_loader("lib") }

    after { loader.unregister }

    it "returns the registered loader managing the directory" do
      expect(described_class.new("lib").loader).to be(loader)
    end

    it "resolves symlinks before comparing directories" do
      File.symlink("lib", "linked")
      expect(described_class.new("linked").loader).to be(loader)
    end

    it "raises NotFound when no loader manages the directory" do
      FileUtils.mkdir_p("other")
      expect { described_class.new("other").loader }.to raise_error(described_class::NotFound, /other/)
    end
  end

  describe "#loader for an inflected namespace" do
    let!(:loader) do
      register_loader("lib") do |l|
        File.write("lib/ecs.rb", "module ECS; end\n")
        l.inflector.inflect("ecs" => "ECS")
      end
    end

    after { loader.unregister }

    it "hands back the loader carrying the project's own inflections" do
      found = described_class.new("lib").loader
      expect(found.cpath_expected_at("lib/ecs.rb")).to eq("ECS")
    end
  end
end
```

The `after { loader.unregister }` matters: loaders live in Zeitwerk's global registry, and a stale loader pointing at a deleted tmpdir would make later `File.realpath` calls raise.

- [ ] **Step 2: Run it to verify it fails**

Run: `bundle exec rspec spec/gempilot/project_loader_spec.rb --no-color`
Expected: FAIL to load — `NameError: uninitialized constant Gempilot::ProjectLoader` (Zeitwerk has no file to autoload it from).

- [ ] **Step 3: Create the class**

Create `lib/gempilot/project_loader.rb`:

```ruby
module Gempilot
  ##
  # The Zeitwerk loader that manages a project's autoload root, located
  # through Zeitwerk's loader registry once the project has been required.
  #
  # Zeitwerk knows which loader owns a directory, and a project's constant
  # names are an inflection performed by that loader, not the other way
  # around. Looking the loader up by directory therefore keeps the project's
  # own inflections in charge: a gem whose entry point sets up +ECS+ rather
  # than +Ecs+ is found without anyone guessing its module name.
  class ProjectLoader
    ##
    # Raised when no registered loader manages the directory.
    class NotFound < Error; end

    ##
    # Absolute, symlink-resolved path of the directory the loader must manage.
    attr_reader :root_dir

    def initialize(root_dir)
      @root_dir = File.realpath(root_dir)
    end

    ##
    # Returns the registered loader whose root directories include
    # +root_dir+, raising NotFound when there is none.
    def loader
      @loader ||= registered_loaders.find { manages?(it) } || raise(NotFound, not_found_message)
    end

    private

    def manages?(loader)
      loader.dirs.any? { File.realpath(it) == root_dir }
    end

    def registered_loaders
      Zeitwerk::Registry.loaders.to_enum(:each)
    end

    def not_found_message
      "No Zeitwerk loader manages #{root_dir}; set one up with Zeitwerk::Loader.for_gem"
    end
  end
end
```

Notes for the implementer:
- `Zeitwerk::Registry` is marked `:nodoc:` upstream, but `Registry.loaders` is the collection `Zeitwerk::Loader.eager_load_all` iterates and has been stable since Zeitwerk 2.0; `to_enum(:each)` is used because `Registry::Loaders` only defines `each` (rubocop's `Style/MapIntoArray` rejects the `each { array << it }` form).
- `ObjectSpace.each_object(Zeitwerk::Loader)` was rejected because JRuby disables `ObjectSpace` by default and gempilot is used under JRuby (issue 986E0100).
- `File.realpath` on both sides makes macOS `/var` vs `/private/var` tmpdirs compare equal.

- [ ] **Step 4: Run the spec to verify it passes, then rubocop**

Run: `bundle exec rspec spec/gempilot/project_loader_spec.rb --no-color && bundle exec rubocop lib/gempilot/project_loader.rb spec/gempilot/project_loader_spec.rb`
Expected: `4 examples, 0 failures`; `2 files inspected, no offenses detected`.

- [ ] **Step 5: Commit**

```bash
git add lib/gempilot/project_loader.rb spec/gempilot/project_loader_spec.rb
git commit -m "Add ProjectLoader to find a gem's Zeitwerk loader by directory"
```

---

### Task 2: `Project` reads VERSION without a module name

**Files:**
- Modify: `lib/gempilot/project.rb` (full rewrite below)
- Modify: `gempilot.gemspec:30` (remove `spec.add_dependency "warning"`), `Gemfile.lock` (via `bundle install`)
- Test: `spec/gempilot/project_spec.rb` (full rewrite below)

**Interfaces:**
- Consumes: `Gempilot::Project::Version` (`Data.define(:path, :value)`, unchanged), `SegmentedVersion` (unchanged).
- Produces: `Project#autoload_root -> Pathname` (parent of `lib_project`: `lib` for `my_gem`, `lib/my_gem` for `my_gem-extension`); `Project#version` unchanged in signature but no longer needs `module_name`; `Project#klass` is removed. `Project#module_name` stays in this task (ZeitwerkTask still calls it) and is removed in Task 3.

- [ ] **Step 1: Rewrite the project spec**

Replace the entire contents of `spec/gempilot/project_spec.rb` with:

```ruby
require "spec_helper"

RSpec.describe Gempilot::Project do
  include FileUtils

  subject(:project) { described_class.new(Dir.pwd) }

  def in_tempdir
    Dir.mktmpdir("project_spec") do |tmpdir|
      chdir tmpdir do
        yield tmpdir
      end
    end
  end

  shared_examples "a gem project" do
    describe "#name" do
      it "derives the gem name from the lib layout" do
        expect(project.name).to eq(expected_name)
      end
    end

    describe "#require_path" do
      it "joins the lib segments with slashes" do
        expect(project.require_path).to eq(expected_require_path)
      end
    end

    describe "#autoload_root" do
      it "is the directory the gem's Zeitwerk loader manages" do
        expect(project.autoload_root.to_s).to end_with(expected_autoload_root)
      end
    end

    describe "#version" do
      it "reads the version value from version.rb" do
        expect(project.version.value).to eq("1.2.3")
      end

      it "points at the version.rb file" do
        expect(project.version.path.to_s).to end_with(version_file)
      end

      it "does not define the gem's modules in the real namespace" do
        project.version
        expect(Object).not_to be_const_defined(root_constant)
      end
    end

    describe "#refresh_version!" do
      it "re-reads the version from disk after a file change" do
        project.version
        File.write(version_file, File.read(version_file).sub("1.2.3", "1.2.4"))
        project.refresh_version!
        expect(project.version.value).to eq("1.2.4")
      end
    end

    describe "#increment_version" do
      it "returns the next patch version" do
        expect(project.increment_version.value).to eq("1.2.4")
      end
    end

    describe "#write_version!" do
      it "replaces the old version string in the file" do
        old_version = project.version
        new_version = project.increment_version
        project.write_version!(old_version, new_version)
        expect(File.read(version_file)).to include("1.2.4")
      end
    end
  end

  describe "a regular gem" do
    let(:expected_name) { "my_gem" }
    let(:expected_require_path) { "my_gem" }
    let(:expected_autoload_root) { "/lib" }
    let(:root_constant) { :MyGem }
    let(:version_file) { "lib/my_gem/version.rb" }

    around do |example|
      in_tempdir do
        Pathname("lib/my_gem").mkpath
        File.write "lib/my_gem.rb", "module MyGem; end\n"
        File.write version_file, <<~RUBY
          module MyGem
            VERSION = "1.2.3".freeze
          end
        RUBY
        example.run
      end
    end

    it_behaves_like "a gem project"

    context "when lib has a .rb file with no matching gem directory" do
      before do
        rm_rf("lib/my_gem")
        rm("lib/my_gem.rb")
        File.write("lib/standalone.rb", "# no matching dir\n")
      end

      it "raises ProjectIntrospectionError" do
        expect { project.name }.to raise_error(Gempilot::Project::ProjectIntrospectionError)
      end
    end

    context "when lib has more than one candidate gem" do
      before do
        Pathname("lib/other").mkpath
        File.write("lib/other.rb", "module Other; end\n")
      end

      it "raises ProjectIntrospectionError naming the ambiguity" do
        expect { project.name }
          .to raise_error(Gempilot::Project::ProjectIntrospectionError, /more than one/)
      end
    end

    context "when version.rb defines no VERSION constant" do
      before { File.write(version_file, "module MyGem\nend\n") }

      it "raises ProjectIntrospectionError naming the file" do
        expect { project.version }
          .to raise_error(Gempilot::Project::ProjectIntrospectionError, /VERSION constant/)
      end
    end
  end

  describe "a gem extension" do
    let(:expected_name) { "my_gem-extension" }
    let(:expected_require_path) { "my_gem/extension" }
    let(:expected_autoload_root) { "/lib/my_gem" }
    let(:root_constant) { :MyGem }
    let(:version_file) { "lib/my_gem/extension/version.rb" }

    around do |example|
      in_tempdir do
        Pathname("lib/my_gem/extension").mkpath
        File.write "lib/my_gem/extension.rb", <<~RUBY
          module MyGem
            module Extension
            end
          end
        RUBY
        File.write version_file, <<~RUBY
          module MyGem
            module Extension
              VERSION = "1.2.3".freeze
            end
          end
        RUBY
        example.run
      end
    end

    it_behaves_like "a gem project"
  end

  describe "a gem whose module name is inflected" do
    let(:version_file) { "lib/ecs/version.rb" }

    around do |example|
      in_tempdir do
        Pathname("lib/ecs").mkpath
        File.write "lib/ecs.rb", "module ECS; end\n"
        File.write version_file, "module ECS\n  VERSION = \"1.2.3\".freeze\nend\n"
        example.run
      end
    end

    it "reads the version without guessing the module name" do
      expect(project.version.value).to eq("1.2.3")
    end
  end
end
```

(Compared with the old spec: the `#module_name` and `#klass` examples are gone, `#autoload_root`, "does not define the gem's modules in the real namespace", the missing-VERSION error, and the inflected-gem example are new. The regex `/VERSION constant/` is deliberately short: `Claude/MysteryRegex` rejects longer inline regexes.)

- [ ] **Step 2: Run it to verify it fails for the right reasons**

Run: `bundle exec rspec spec/gempilot/project_spec.rb --no-color`
Expected: failures — `NoMethodError: undefined method 'autoload_root'` (×2), "does not define the gem's modules" fails because today `load` defines `::MyGem` (×2), the inflected gem raises `NameError: uninitialized constant Ecs` from `Object.const_get("Ecs")`, and the missing-VERSION example gets `NameError` instead of `ProjectIntrospectionError`. Everything else passes.

- [ ] **Step 3: Rewrite Project**

Replace the entire contents of `lib/gempilot/project.rb` with:

```ruby
module Gempilot
  ##
  # Introspects a gem project to discover its name, require path, autoload
  # root, and version. Works for both regular gems (+lib/my_gem.rb+) and
  # extension gems whose entry point nests deeper (+lib/my_gem/extension.rb+
  # for +my_gem-extension+).
  #
  # The version is read by loading +version.rb+ under a throwaway module, so
  # the project's module name is never needed and reloading after a bump
  # never redefines a real constant.
  class Project
    class ProjectIntrospectionError < StandardError; end

    using String::Inflectable

    attr_reader :root

    def initialize(root = Dir.pwd)
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
      project_segments.join("-")
    end

    def require_path
      project_segments.join("/")
    end

    def module_name
      project_segments.map(&:camelize).join("::")
    end

    ##
    # The directory a loader set up with +for_gem+ or +for_gem_extension+
    # manages: the parent of the project's namespace directory.
    def autoload_root
      lib_project.parent
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

    def project_segments
      lib_project.relative_path_from(lib).each_filename.to_a
    end

    def with_version_file
      version.path.open(File::RDWR, 0o644) do |f|
        f.flock File::LOCK_EX
        yield f
        f.truncate(f.pos)
      end
    end

    def fetch_lib_project
      dirs = shallowest_entry_dirs
      case dirs.count
      in 0 then raise ProjectIntrospectionError, "Could not identify project dir"
      in (2..)
        msg = "Found more than one possible project name:\n  - #{dirs.join("\n  - ")}"
        raise ProjectIntrospectionError, msg
      in 1 then dirs.first
      end
    end

    def shallowest_entry_dirs
      entry_dirs.group_by { depth_below_lib(it) }
                .min_by(&:first)
                &.last || []
    end

    def entry_dirs
      lib.glob("**/*.rb")
         .map { it.sub_ext("") }
         .select(&:directory?)
    end

    def depth_below_lib(path)
      path.relative_path_from(lib).each_filename.count
    end

    def fetch_version
      path = lib_project.join("version.rb").tap { verify_existence! it }
      Version.new(path:, value: version_defined_in(path))
    end

    # Loads the version file under an anonymous module so the modules it opens
    # live there instead of in the real namespace, then walks that private
    # module tree down to VERSION.
    def version_defined_in(path)
      sandbox = Module.new
      load path.to_s, sandbox
      version_in(sandbox) || raise(ProjectIntrospectionError, "Expected #{path} to define a VERSION constant")
    end

    def version_in(mod)
      return mod.const_get(:VERSION, false) if mod.const_defined?(:VERSION, false)

      mod.constants(false)
         .map { mod.const_get(it, false) }
         .grep(Module)
         .filter_map { version_in(it) }
         .first
    end

    def verify_existence!(path)
      return true if @verifications.member? path

      raise ProjectIntrospectionError, "Expected #{path} to exist but does not" unless path.exist?

      @verifications.add path
    end
  end
end
```

What changed: `require "warning"`, the two `*_WARNING` constants and the `Warning.ignore` calls are gone (each load uses a fresh anonymous module, so nothing is ever redefined); `klass` is gone; `fetch_version` delegates to `version_defined_in` / `version_in`; `autoload_root` is new; `module_name` is kept only until Task 3. `load(path, module)` runs the file with the module as its lexical scope, so `module MyGem` inside `version.rb` creates `sandbox::MyGem`, never touching `::MyGem` (verified with plain Ruby on 2026-09-23, including the nested extension shape and a pre-existing top-level `MyGem`).

- [ ] **Step 4: Run the spec and the neighbours that depend on Project**

Run: `bundle exec rspec spec/gempilot/project_spec.rb spec/gempilot/version_task_spec.rb spec/gempilot/zeitwerk_task_spec.rb spec/zeitwerk_spec.rb --no-color && bundle exec rubocop lib/gempilot/project.rb spec/gempilot/project_spec.rb`
Expected: all examples pass (`version_task_spec` still bumps `1.0.0.dev3` correctly; `zeitwerk_task_spec` still passes because `module_name` still exists); `2 files inspected, no offenses detected`.

- [ ] **Step 5: Drop the warning dependency**

In `gempilot.gemspec` delete the line:

```ruby
  spec.add_dependency "warning"
```

Then run `bundle install 2>&1 | tail -2` (expected `Bundle complete!`; `git diff Gemfile.lock` removes `warning` from the `gempilot` PATH spec and, since nothing else depends on it, from the `GEM` specs and `CHECKSUMS`).

Verify nothing else references it: `grep -rn "warning" lib gempilot.gemspec Gemfile` must print nothing.

- [ ] **Step 6: Full gate and commit**

Run: `bundle exec rake default 2>&1 | tail -8`
Expected: RSpec `198 examples, 0 failures` (196 after Task 1, plus the two net-new project examples), RuboCop no offenses, minitest unchanged from baseline.

```bash
git add lib/gempilot/project.rb spec/gempilot/project_spec.rb gempilot.gemspec Gemfile.lock
git commit -m "Read VERSION in a sandbox instead of guessing the module name"
```

---

### Task 3: `ZeitwerkTask` asks Zeitwerk for the loader

**Files:**
- Modify: `lib/gempilot/zeitwerk_task.rb` (full rewrite below)
- Modify: `lib/gempilot/project.rb` (delete `module_name` and the now-unused `using String::Inflectable`)
- Test: `spec/gempilot/zeitwerk_task_spec.rb` (full rewrite below)

**Interfaces:**
- Consumes: `Gempilot::ProjectLoader.new(root_dir).loader` (Task 1), `Project#autoload_root` and `Project#require_path` (Task 2).
- Produces: unchanged task names `zeitwerk:validate` and `zeitwerk:all`; child scripts that `require "gempilot"` and the gem, then use the found loader. `Project#module_name` no longer exists after this task (grep confirms it has no other callers).

- [ ] **Step 1: Rewrite the task spec with an inflected-gem fixture**

Replace the entire contents of `spec/gempilot/zeitwerk_task_spec.rb` with:

```ruby
require "spec_helper"

RSpec.describe Gempilot::ZeitwerkTask do
  around do |example|
    old_app = Rake.application
    Rake.application = Rake::Application.new
    Dir.mktmpdir("zeitwerk_task_spec") do |tmpdir|
      Dir.chdir(tmpdir) { example.run }
    end
  ensure
    Rake.application = old_app
  end

  def write_gem(name:, mod:, inflections: {})
    FileUtils.mkdir_p("lib/#{name}")
    File.write("#{name}.gemspec", %(Gem::Specification.new { |s| s.name = "#{name}" }))
    File.write("lib/#{name}.rb", <<~RUBY)
      require "zeitwerk"
      module #{mod}
        LOADER = Zeitwerk::Loader.for_gem.tap do |l|
          l.inflector.inflect(#{inflections.inspect})
          l.setup
        end
      end
    RUBY
    File.write("lib/#{name}/version.rb", "module #{mod}\n  VERSION = \"1.0.0\".freeze\nend\n")
  end

  describe "task definitions" do
    before do
      write_gem(name: "my_gem", mod: "MyGem")
      described_class.new(root: Dir.pwd)
    end

    it "defines zeitwerk:validate" do
      expect(Rake::Task).to be_task_defined("zeitwerk:validate")
    end

    it "defines zeitwerk:all" do
      expect(Rake::Task).to be_task_defined("zeitwerk:all")
    end
  end

  describe "zeitwerk:validate" do
    before do
      write_gem(name: "my_gem", mod: "MyGem")
      described_class.new(root: Dir.pwd)
    end

    it "passes for a conventionally-named gem" do
      expect { Rake::Task["zeitwerk:validate"].invoke }.not_to raise_error
    end

    context "when a file breaks the naming convention" do
      before { File.write("lib/my_gem/oops.rb", "module MyGem; class Correct; end; end\n") }

      it "fails" do
        expect { Rake::Task["zeitwerk:validate"].invoke }.to raise_error(RuntimeError)
      end
    end
  end

  describe "zeitwerk:all" do
    before do
      write_gem(name: "my_gem", mod: "MyGem")
      described_class.new(root: Dir.pwd)
    end

    it "lists the constants the loader expects" do
      expect { Rake::Task["zeitwerk:all"].invoke }.to output(/MyGem::VERSION/).to_stdout_from_any_process
    end
  end

  describe "a gem whose loader inflects its module name" do
    before do
      write_gem(name: "ecs", mod: "ECS", inflections: { "ecs" => "ECS" })
      described_class.new(root: Dir.pwd)
    end

    it "validates through the gem's own loader" do
      expect { Rake::Task["zeitwerk:validate"].invoke }.not_to raise_error
    end

    it "lists constants under the inflected namespace" do
      expect { Rake::Task["zeitwerk:all"].invoke }.to output(/ECS::VERSION/).to_stdout_from_any_process
    end
  end
end
```

`to_stdout_from_any_process` is required because the tasks print from a child `ruby` process.

- [ ] **Step 2: Run it to verify the inflected examples fail**

Run: `bundle exec rspec spec/gempilot/zeitwerk_task_spec.rb --no-color`
Expected: `7 examples, 2 failures` — both examples in "a gem whose loader inflects its module name" fail: the child process prints `uninitialized constant Ecs (NameError)` and Rake's `ruby` raises `RuntimeError: Command failed with status (1)`. The five `my_gem` examples pass.

- [ ] **Step 3: Rewrite ZeitwerkTask**

Replace the entire contents of `lib/gempilot/zeitwerk_task.rb` with:

```ruby
require "rake/tasklib"
require_relative "../gempilot"

module Gempilot
  ##
  # Rake tasks for validating and inspecting a gem's Zeitwerk loader.
  #
  # Owned by gempilot and consumed by generated gems, whose Rakefile requires
  # <tt>gempilot/zeitwerk_task</tt> and instantiates <tt>Gempilot::ZeitwerkTask.new</tt>,
  # so the logic rolls forward on a gempilot bump instead of being copied into
  # every gem's Rakefile.
  #
  # Each task boots a clean child process that requires the gem and then asks
  # Zeitwerk for the loader managing the gem's autoload root (see
  # ProjectLoader). The gem's own inflections stay in charge, so a gem whose
  # entry point sets up +ECS+ rather than +Ecs+ validates like any other, and
  # eager loading never pollutes the Rake process.
  class ZeitwerkTask < Rake::TaskLib
    attr_reader :project

    def initialize(root: Dir.pwd)
      super()
      @project = Project.new(root)
      define_tasks
    end

    private

    def define_tasks
      namespace :zeitwerk do
        define_validate_task
        define_all_task
      end
    end

    def define_validate_task
      desc "Verify all files follow Zeitwerk naming conventions"
      task(:validate) { ruby "-Ilib", "-e", validate_script }
    end

    def define_all_task
      desc "List every constant Zeitwerk manages and the file it expects"
      task(:all) { ruby "-Ilib", "-e", all_script }
    end

    def loader_script
      <<~RUBY
        require "gempilot"
        require #{project.require_path.inspect}
        loader = Gempilot::ProjectLoader.new(#{project.autoload_root.to_s.inspect}).loader
      RUBY
    end

    def validate_script
      <<~RUBY
        #{loader_script}
        loader.eager_load(force: true)
        puts "Zeitwerk: All files loaded successfully."
      RUBY
    end

    def all_script
      <<~RUBY
        #{loader_script}
        rows = loader.all_expected_cpaths.sort_by(&:last)
        width = rows.map { |_path, cpath| cpath.length }.max || 0
        rows.each { |path, cpath| puts format("%-\#{width}s  %s", cpath, path) }
      RUBY
    end
  end
end
```

This is also the documentation fix from the issue: the class doc is now a canonical rdoc block (bare `##`, then `#` lines, paragraphs separated by `#`) and the usage is prose with two `<tt>` spans instead of a two-statement snippet crammed into one `<tt>` with a semicolon. A verbatim (indented) code sample was rejected on purpose: `Claude/NoCommentedCode` flags a comment line such as `#   require "gempilot/zeitwerk_task"` as commented-out code. The child requires `gempilot` (already in every generated gem's bundle, since the Rakefile requires `gempilot/zeitwerk_task`) so that `ProjectLoader` is available in the child; `require_path` and `autoload_root` are interpolated with `inspect` so any path is quoted correctly.

- [ ] **Step 4: Delete `module_name` from Project**

In `lib/gempilot/project.rb` remove these two pieces (nothing else calls them; confirm with `grep -rn "module_name\|Inflectable" lib`, which must only show `gem_constant.rb`, `gem_context.rb`, `create.rb`, `new.rb`, `destroy.rb` afterwards):

```ruby
    using String::Inflectable
```

```ruby
    def module_name
      project_segments.map(&:camelize).join("::")
    end
```

- [ ] **Step 5: Run the specs and rubocop**

Run: `bundle exec rspec spec/gempilot/zeitwerk_task_spec.rb spec/gempilot/project_spec.rb spec/gempilot/project_loader_spec.rb spec/zeitwerk_spec.rb --no-color && bundle exec rubocop lib/gempilot/zeitwerk_task.rb lib/gempilot/project.rb spec/gempilot/zeitwerk_task_spec.rb`
Expected: all pass (`7 examples` in the task spec, including both `ECS` examples); `3 files inspected, no offenses detected`.

- [ ] **Step 6: Full gate and commit**

Run: `bundle exec rake default 2>&1 | tail -8`
Expected: RSpec `0 failures`, RuboCop no offenses, minitest as in the baseline.

```bash
git add lib/gempilot/zeitwerk_task.rb lib/gempilot/project.rb spec/gempilot/zeitwerk_task_spec.rb
git commit -m "Locate the gem's Zeitwerk loader through Zeitwerk instead of a guessed constant"
```

---

### Task 4: Documentation updates

**Files:**
- Modify: `CLAUDE.md` (Architecture list; Generated Gem Features list)
- Modify: `README.md` (Generated Gem Features list)

**Interfaces:**
- Consumes: final behaviour from Tasks 1–3. No code.

- [ ] **Step 1: Update CLAUDE.md**

In the Architecture list, replace the `GemConstant` bullet's neighbour context by adding, after the `SegmentedVersion` bullet:

```markdown
- `ProjectLoader` (`lib/gempilot/project_loader.rb`) finds the Zeitwerk loader that manages a directory through `Zeitwerk::Registry`; `ZeitwerkTask` child scripts use it, so a gem's own `inflector.inflect` rules (e.g. `ECS`) are honoured and no module name is ever guessed from a path
- `Project` (`lib/gempilot/project.rb`) knows a gem's name, require path, autoload root, and version; the version is read by `load`ing `version.rb` under an anonymous module, so `Project` never derives or needs the gem's module name (there is deliberately no `module_name`/`klass`)
```

In the Generated Gem Features list, change the Zeitwerk bullet to:

```markdown
- `rake zeitwerk:validate` / `rake zeitwerk:all` tasks provided by `Gempilot::ZeitwerkTask`, which locate the gem's loader through Zeitwerk (inflected namespaces such as `ECS` work)
```

- [ ] **Step 2: Update README.md**

In "Generated Gem Features", change the Zeitwerk bullet to:

```markdown
- **Zeitwerk autoloading** with `LOADER` constant, `rake zeitwerk:validate`, and
  `rake zeitwerk:all`; the tasks find the loader through Zeitwerk itself, so
  custom inflections (`loader.inflector.inflect("ecs" => "ECS")`) just work
```

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md README.md
git commit -m "Document ProjectLoader and the module-name-free Project"
```

---

### Task 5: Bring every doc block under lib/ to rdoc's canonical form

The issue's first point ("documentation is improperly formatted, sizing is all over the place") comes from the `## text` on-every-line style used throughout `lib/`: renderers that treat the comment body as Markdown (IDE hovers) turn each `## ...` line into a heading. rdoc's own convention, already used by every ERB template gempilot generates (`data/templates/gem/lib/gem_name.rb.erb`) and by the idiomatic-ruby skill, is a bare `##` marker followed by `# ` lines. Tasks 1–3 wrote their files that way; this task converts the remaining 22 files mechanically.

**Files:**
- Modify: every `lib/**/*.rb` still containing lines that start with `## ` (22 files; `grep -rln "^\s*## " lib` lists them)
- Test: existing suite + `bundle exec rubocop lib` + an rdoc render

**Interfaces:**
- Consumes/produces: comments only; no code changes.

- [ ] **Step 1: Run the conversion script**

Save this as a scratch file outside the repo (it is a one-off tool, not committed), then run it from the repo root with `ruby <path>/doc_sweep.rb`:

```ruby
# Converts per-line "## text" doc blocks under lib/ to rdoc's canonical form:
# a bare "##" marker line followed by "# text" lines. Blocks that already
# start with a bare "##" are left alone.
Dir.glob("lib/**/*.rb").sort.each do |path|
  lines = File.readlines(path)
  out = []
  i = 0
  while i < lines.size
    line = lines[i]
    indent = line[/\A\s*/]
    if line.start_with?("#{indent}## ")
      out << "#{indent}##\n"
      while i < lines.size && (lines[i].start_with?("#{indent}## ") || lines[i].chomp == "#{indent}##")
        out << lines[i].sub("##", "#")
        i += 1
      end
    else
      out << line
      i += 1
    end
  end
  File.write(path, out.join)
end
```

A per-line block such as

```ruby
  ## Commit-message prefix written for a version bump; the guard below
  ## matches on it, so the two must stay in sync.
  BUMP_MESSAGE_PREFIX = "Bump version to ".freeze
```

becomes

```ruby
  ##
  # Commit-message prefix written for a version bump; the guard below
  # matches on it, so the two must stay in sync.
  BUMP_MESSAGE_PREFIX = "Bump version to ".freeze
```

- [ ] **Step 2: Check nothing was missed and nothing else changed**

Run: `grep -rn "^\s*## " lib || echo none` (expected: `none`), then `git diff --stat | tail -1` (expected: `22 files changed`; every hunk replaces `## text` lines with `# text` lines and adds one bare `##` marker line per block, so insertions exceed deletions by the number of blocks). Spot-check `git diff lib/gempilot/gem_constant.rb`: every changed hunk touches comment lines only.

- [ ] **Step 3: Run rubocop on lib, the full suite, and an rdoc render**

Run: `bundle exec rubocop lib`
Expected: `27 files inspected, no offenses detected`. (`Claude/NoCommentedCode` now sees the prose for the first time because a `## text` line used to reach the cop as `# text`; when this sweep was rehearsed on 2026-09-23 no line tripped it. If a future line does, reword that sentence so it does not start like a bare identifier, assignment, or `require`.)

Run: `rdoc --quiet --op /tmp/gempilot-rdoc lib && ruby -e 'puts File.read("/tmp/gempilot-rdoc/Gempilot/ZeitwerkTask.html")[/<section class="description">.*?<\/section>/m]'`
Expected: three `<p>` paragraphs, the second containing `<code>gempilot/zeitwerk_task</code>` and a link to `ZeitwerkTask.new`, the third linking `ProjectLoader`. Delete `/tmp/gempilot-rdoc` afterwards.

Run: `bundle exec rake default 2>&1 | tail -8`
Expected: unchanged counts, no failures, no offenses.

- [ ] **Step 4: Commit**

```bash
git add lib
git commit -m "Bring lib doc comments to rdoc's canonical form"
```
