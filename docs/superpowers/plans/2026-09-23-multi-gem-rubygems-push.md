# Multi-Gem RubyGems Push Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `rake release:rubygems` push every gem in `pkg/` that belongs to the version being released (the plain gem plus any platform gems), and abort when there is none, instead of inheriting bundler's `release:rubygem_push`, which pushes exactly one file.

**Architecture:** gempilot takes ownership of `release:rubygem_push` the same way it already owns `release:source_control_push`: `ReleaseTasks` clears bundler's task and redefines it (still depending on `build`) to call a new `Gempilot::RubygemsRelease`, a small `StrictShell` collaborator in the style of `GithubRelease`/`Origin`. `RubygemsRelease` derives the package list from what `Project` already knows (`name`, `version_value`, `root`) with a version-scoped brace glob, so `my_gem-1.2.30.gem` and `my_gem-1.2.3.1.gem` left over in `pkg/` are never re-pushed. The prerequisite chain of `release:rubygems` (`build`, `release:guard_clean`, `release:source_control_push`, `release:rubygem_push`) is unchanged.

**Tech Stack:** Ruby 4.0, Rake (`Rake::Task#clear`, task prerequisites), `Pathname#glob` with `{a,b}` braces, RSpec with `instance_double` and `have_received(...).ordered`.

**Issue:** `F6C6EB04-8DA4-11F1-91EF-FA41C3164F3A` — "release:rubygem_push only handles one gem per version".

## Global Constraints

- Ruby `>= 4.0`; `it` block parameter is fine.
- Double-quoted strings (`Style/StringLiterals: double_quotes`); NO `# frozen_string_literal:` comments; trailing commas in multiline literals/arguments.
- rdoc doc blocks in canonical form (a bare `##` line, then `# ...` lines; never a comment line that reads like code — `Claude/NoCommentedCode`).
- Zeitwerk: new file `lib/gempilot/rubygems_release.rb` MUST define `Gempilot::RubygemsRelease` (`spec/zeitwerk_spec.rb` eager-loads gempilot).
- Out of scope, deliberately: bundler's `gem_push=no` environment switch and its `--key`/`--host` options are not reproduced (gempilot's `release:github` is the way to skip RubyGems; nothing in the templates sets `allowed_push_host`).
- `gem push` needs an interactive OTP prompt when `rubygems_mfa_required` is set; `StrictShell#sh` runs through `Kernel#system`, so stdin is inherited and the prompt works.
- Verification: `bundle exec rspec <files>` for focused runs, `bundle exec rubocop <files>` per task, `bundle exec rake default` for the full gate.
- Baseline (verified 2026-09-23): RSpec `192 examples, 0 failures`; RuboCop no offenses; minitest `109 runs, 4 failures` — the 4 are the Gemfile-template ordering regression fixed by Task 1 of `docs/superpowers/plans/2026-09-23-land-betterleaks-jruby.md`; apply that one-line change first for a fully green gate. Final state after this plan: RSpec `199 examples, 0 failures`, minitest unchanged.
- Commit messages: plain imperative sentences, no conventional-commit prefixes.

---

### Task 1: `Gempilot::RubygemsRelease`

**Files:**
- Create: `lib/gempilot/rubygems_release.rb`
- Test: `spec/gempilot/rubygems_release_spec.rb`

**Interfaces:**
- Consumes: `Gempilot::StrictShell#sh` (raises on non-zero exit), `Project#name`, `Project#version_value`, `Project#root` (Pathname).
- Produces: `Gempilot::RubygemsRelease.new(project) -> RubygemsRelease`, `#push -> void` (runs `gem push <path>` for each package in sorted order; raises `RuntimeError` "No packages for <name> <version> found in pkg/; run rake build first" when there is none). Task 2 relies on `RubygemsRelease.new(project).push`.

- [ ] **Step 1: Write the failing spec**

Create `spec/gempilot/rubygems_release_spec.rb`:

```ruby
require "spec_helper"

RSpec.describe Gempilot::RubygemsRelease do
  let(:project) { Gempilot::Project.new(Dir.pwd) }
  let(:release) { described_class.new(project) }
  let(:no_packages_error) { %r{No packages for my_gem 1\.2\.3 found in pkg/; run rake build first} }

  around do |example|
    Dir.mktmpdir("rubygems_release_spec") { |dir| Dir.chdir(dir) { example.run } }
  end

  before do
    Pathname("lib/my_gem").mkpath
    File.write "lib/my_gem.rb", "module MyGem; end\n"
    File.write "lib/my_gem/version.rb", <<~RUBY
      module MyGem
        VERSION = "1.2.3".freeze
      end
    RUBY
    allow(release).to receive(:sh)
  end

  def package(*names)
    Pathname("pkg").mkpath
    names.each { FileUtils.touch("pkg/#{it}") }
  end

  def pkg(name)
    project.root.join("pkg", name).to_s
  end

  describe "#push" do
    it "pushes the plain gem of the current version" do
      package "my_gem-1.2.3.gem"
      release.push
      expect(release).to have_received(:sh).with("gem", "push", pkg("my_gem-1.2.3.gem"))
    end

    it "pushes every gem of the current version in sorted order", :aggregate_failures do
      package "my_gem-1.2.3.gem", "my_gem-1.2.3-x86_64-linux.gem", "my_gem-1.2.3-arm64-darwin.gem"
      release.push
      expect(release).to have_received(:sh).with("gem", "push", pkg("my_gem-1.2.3-arm64-darwin.gem")).ordered
      expect(release).to have_received(:sh).with("gem", "push", pkg("my_gem-1.2.3-x86_64-linux.gem")).ordered
      expect(release).to have_received(:sh).with("gem", "push", pkg("my_gem-1.2.3.gem")).ordered
    end

    context "when pkg also holds other versions and other gems" do
      before { package "my_gem-1.2.3.gem", "my_gem-1.2.30.gem", "my_gem-1.2.3.1.gem", "other-1.2.3.gem" }

      it "pushes only the gems of the current version", :aggregate_failures do
        release.push
        expect(release).to have_received(:sh).with("gem", "push", pkg("my_gem-1.2.3.gem"))
        expect(release).to have_received(:sh).once
      end
    end

    it "raises without pushing when pkg holds no gem of the current version", :aggregate_failures do
      package "my_gem-1.2.30.gem"
      expect { release.push }.to raise_error(RuntimeError, no_packages_error)
      expect(release).not_to have_received(:sh)
    end

    it "raises when pkg does not exist" do
      expect { release.push }.to raise_error(RuntimeError, no_packages_error)
    end
  end
end
```

(The error regex is a named `let` because `Claude/MysteryRegex` rejects long inline regexes.)

- [ ] **Step 2: Run it to verify it fails**

Run: `bundle exec rspec spec/gempilot/rubygems_release_spec.rb --no-color`
Expected: FAIL to load — `NameError: uninitialized constant Gempilot::RubygemsRelease`.

- [ ] **Step 3: Create the class**

Create `lib/gempilot/rubygems_release.rb`:

```ruby
module Gempilot
  ##
  # Pushes every gem of the version being released to RubyGems. Backs the
  # +release:rubygem_push+ task in place of bundler's, which pushes only the
  # single gem its own +build+ task produced. A project that builds several
  # gems per version (platform gems carrying a compiled executable alongside
  # the plain ruby gem) needs all of them pushed, so this globs +pkg/+ for the
  # packages of that version: <tt>name-version.gem</tt> and
  # <tt>name-version-platform.gem</tt>. The glob is scoped to the exact version
  # because +pkg/+ is never emptied between releases; a looser
  # <tt>name-version*.gem</tt> would also sweep up <tt>name-1.2.30.gem</tt> and
  # <tt>name-1.2.3.1.gem</tt> and re-push versions already on RubyGems. Finding
  # no package at all aborts the release, since a release that published
  # nothing must not report success.
  class RubygemsRelease
    include StrictShell

    attr_reader :project

    def initialize(project)
      @project = project
    end

    def push
      paths = packages
      raise "No packages for #{name_and_version} found in pkg/; run rake build first" if paths.empty?

      paths.each { sh "gem", "push", it.to_s }
    end

    private

    def name_and_version
      "#{project.name} #{project.version_value}"
    end

    def packages
      stem = "#{project.name}-#{project.version_value}"
      project.root.glob("pkg/{#{stem}.gem,#{stem}-*.gem}").sort
    end
  end
end
```

`Pathname#glob` delegates to `Dir.glob`, which expands `{a,b}` braces by default (verified: for stem `foo-0.3.0` the pattern matches `foo-0.3.0.gem` and `foo-0.3.0-x86_64-linux.gem` and not `foo-0.3.10.gem` or `foo-0.3.0.1.gem`). `Project#root` is a `Pathname`, so the results are absolute `Pathname`s; `sh` gets them as strings. Keep the `.sort`: `Dir.glob` returns the first brace alternative's matches before the second's, so without it the plain gem would come first and the sorted-order example would fail. A missing `pkg/` directory simply globs to `[]`, which is why "raises when pkg does not exist" needs no extra code.

- [ ] **Step 4: Run the spec and rubocop**

Run: `bundle exec rspec spec/gempilot/rubygems_release_spec.rb spec/zeitwerk_spec.rb --no-color && bundle exec rubocop lib/gempilot/rubygems_release.rb spec/gempilot/rubygems_release_spec.rb`
Expected: `6 examples, 0 failures`; `2 files inspected, no offenses detected`.

- [ ] **Step 5: Commit**

```bash
git add lib/gempilot/rubygems_release.rb spec/gempilot/rubygems_release_spec.rb
git commit -m "Add RubygemsRelease to push every gem of a version"
```

---

### Task 2: Own `release:rubygem_push`

**Files:**
- Modify: `lib/gempilot/release_tasks.rb`
- Test: `spec/gempilot/version_task_spec.rb`

**Interfaces:**
- Consumes: `RubygemsRelease.new(project).push` (Task 1), `ReleaseTasks#clear_task`, Rake DSL `task`.
- Produces: task `release:rubygem_push` with prerequisites exactly `["build"]`, whose action is `RubygemsRelease.new(project).push`; bundler's action for that task is cleared. `release:rubygems`'s prerequisite chain is unchanged.

- [ ] **Step 1: Add the failing examples**

In `spec/gempilot/version_task_spec.rb`, inside `describe "release task hierarchy"`, after the example "builds release:rubygems from bundler's own tasks", add:

```ruby
    it "builds before pushing to RubyGems" do
      expect(Rake::Task["release:rubygem_push"].prerequisites).to eq(["build"])
    end
```

Inside `describe "release task behavior"`, extend the doubles:

```ruby
    let(:origin) { instance_double(Gempilot::Origin, push: nil) }
    let(:github) { instance_double(Gempilot::GithubRelease, create: nil, destroy: nil, list: nil) }
    let(:rubygems) { instance_double(Gempilot::RubygemsRelease, push: nil) }

    before do
      allow(Gempilot::Origin).to receive(:new).and_return(origin)
      allow(Gempilot::GithubRelease).to receive(:new).and_return(github)
      allow(Gempilot::RubygemsRelease).to receive(:new).and_return(rubygems)
    end
```

and, after the example "release:source_control_push pushes via Origin", add:

```ruby
    it "release:rubygem_push pushes every package via RubygemsRelease" do
      Rake::Task["release:rubygem_push"].execute
      expect(rubygems).to have_received(:push)
    end
```

(`execute` rather than `invoke`: this spec does not load `bundler/gem_tasks`, so the `build` prerequisite does not exist in its Rake application; `execute` runs the action without prerequisites.)

- [ ] **Step 2: Run to verify the new examples fail**

Run: `bundle exec rspec spec/gempilot/version_task_spec.rb --no-color`
Expected: `16 examples, 2 failures` — "builds before pushing to RubyGems" fails with `Don't know how to build task 'release:rubygem_push'` (no such task without bundler), and the behavior example fails the same way.

- [ ] **Step 3: Define the task in ReleaseTasks**

In `lib/gempilot/release_tasks.rb`, replace the module doc block and `define_release_tasks`, and add `define_rubygem_push` right after `override_source_control_push`:

```ruby
module Gempilot
  ##
  # Rake task definitions for publishing a release to RubyGems and GitHub.
  # Mixed into VersionTask. Assumes +bundler/gem_tasks+ has been required so the
  # +build+ and +release:guard_clean+ tasks exist (the generated Rakefile
  # guarantees this). Replaces two of bundler's release steps: its
  # +already_tagged?+-guarded +release:source_control_push+ with an idempotent
  # push, and its single-gem +release:rubygem_push+ with RubygemsRelease, which
  # pushes every gem in +pkg/+ built for the released version.
  module ReleaseTasks
    private

    def define_release_tasks(project)
      override_source_control_push(project)
      define_rubygem_push(project)
      define_release_namespace(project)
      define_root_release_task
      define_unrelease_tasks(project)
    end

    def override_source_control_push(project)
      clear_task "release:source_control_push"
      task("release:source_control_push") { Origin.new(project.version_tag).push }
    end

    def define_rubygem_push(project)
      clear_task "release:rubygem_push"
      task("release:rubygem_push" => "build") { RubygemsRelease.new(project).push }
    end
```

Everything from `define_release_namespace` down is unchanged. `Rake::Task#clear` drops bundler's prerequisites and action but keeps the task registered, so redefining it with `=> "build"` yields the same single prerequisite the spec pins.

- [ ] **Step 4: Run the spec and rubocop, then the full gate**

Run: `bundle exec rspec spec/gempilot/version_task_spec.rb spec/gempilot/rubygems_release_spec.rb --no-color && bundle exec rubocop lib/gempilot/release_tasks.rb spec/gempilot/version_task_spec.rb`
Expected: `21 examples, 0 failures`; `2 files inspected, no offenses detected`.

Run: `bundle exec rake default 2>&1 | tail -8`
Expected: RSpec `199 examples, 0 failures`, RuboCop no offenses, minitest as in the baseline.

- [ ] **Step 5: Commit**

```bash
git add lib/gempilot/release_tasks.rb spec/gempilot/version_task_spec.rb
git commit -m "Push every gem of the released version to RubyGems"
```

---

### Task 3: Documentation

**Files:**
- Modify: `README.md` (Version Management Tasks table)
- Modify: `CLAUDE.md` (Generated Gem Features, publishing bullet)

**Interfaces:**
- Consumes: final behaviour of Tasks 1–2. No code.

- [ ] **Step 1: README**

Change the `rake release:rubygems` row to:

```markdown
| `rake release:rubygems` | Build, then push every gem in `pkg/` for the current version to RubyGems |
```

- [ ] **Step 2: CLAUDE.md**

Replace the publishing bullet (the one starting "Publishing rake tasks") with:

```markdown
- Publishing rake tasks (mixed into `VersionTask` via `Gempilot::ReleaseTasks`): `release` (all remotes), `release:rubygems`, `release:github`, `release:list:github`, `unrelease`, `unrelease:github`. These override and reuse bundler's `bundler/gem_tasks` release chain; `release:source_control_push` is replaced with `Gempilot::Origin` to push commit+tag idempotently, and `release:rubygem_push` is owned by gempilot (`Gempilot::RubygemsRelease`) and pushes every `pkg/<name>-<version>{,-*}.gem` rather than bundler's single built gem
```

- [ ] **Step 3: Commit**

```bash
git add README.md CLAUDE.md
git commit -m "Document the version-scoped RubyGems push"
```
