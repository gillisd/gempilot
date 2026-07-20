# Release Task Hierarchy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move GitHub publishing out of the `version:github:*` namespace into the idiomatic `release` / `unrelease` namespace, and fix GitHub releasing (bundler's `already_tagged?` guard silently skips the git push).

**Architecture:** A new `Gempilot::Origin` object does an idempotent commit+tag push and replaces bundler's buggy `release:source_control_push`. RubyGems publishing reuses bundler's own `build` / `release:guard_clean` / `release:rubygem_push` leaf tasks via prerequisites; GitHub publishing uses the existing (slimmed) `GithubRelease`. All task wiring lives in a new `Gempilot::ReleaseTasks` module mixed into `VersionTask`. Bare `rake release` is a pure prerequisite composite over both remotes — no arguments, no dispatcher code.

**Tech Stack:** Ruby, Rake (`Rake::TaskLib`, `bundler/gem_tasks`), Zeitwerk autoloading, RSpec (unit specs) + Minitest (generator tests), RuboCop (`rubocop-claude`/`-rspec`/`-performance`/`-rake`/`-design`).

**Spec:** `docs/superpowers/specs/2026-07-20-release-task-hierarchy-design.md`

---

## Preconditions

- Branch `release-task-hierarchy` is checked out.
- `bundle install` works and the baseline is green:
  - `bundle exec rake spec` → `106 examples, 0 failures`
  - `bundle exec rake test` → `108 runs, 0 failures`
  - `bundle exec rubocop` → `no offenses detected`
- If `bundle install` fails with `Bundler::Plugin::Index::SourceConflict (Source(s) 'vault' ...)`, align the local plugin index to the installed vault plugin version, then reinstall:
  ```bash
  ruby -e 'f=".bundle/plugin/index"; File.write(f, File.read(f).gsub("bundler-source-vault-0.1.2","bundler-source-vault-0.1.5"))'
  bundle install
  ```
  (`.bundle/` is not tracked by git — this is a local-environment fix only.)

## Final target — task interface

| Task | Behavior |
| --- | --- |
| `rake release` | Publish current version to all remotes (RubyGems + GitHub) |
| `rake release:rubygems` | Build + push the gem to RubyGems |
| `rake release:github` | Push commit + tag, then create the GitHub release |
| `rake release:list:github` | List GitHub releases |
| `rake unrelease` | Delete the release from all remotes that support it (GitHub) |
| `rake unrelease:github` | Delete the GitHub release and remote tag |

`version:github:release/unrelease/list` are removed. `version:*` lifecycle tasks and the `version:release`/`version:unrelease` composites are unchanged.

---

## Task 1: `Gempilot::Origin` (idempotent commit + tag push)

**Files:**
- Create: `lib/gempilot/origin.rb`
- Test: `spec/gempilot/origin_spec.rb`

This is the bug fix: an always-push, no-guard replacement for bundler's `release:source_control_push`. Mirrors bundler's `git_push` (push the branch ref, then the tag ref, to the branch's configured remote — defaulting to `origin`).

- [ ] **Step 1: Write the failing spec**

Create `spec/gempilot/origin_spec.rb`:

```ruby
require "spec_helper"

RSpec.describe Gempilot::Origin do
  subject(:origin) { described_class.new("v1.2.3") }

  around do |example|
    Dir.mktmpdir("origin_spec") { |dir| Dir.chdir(dir) { example.run } }
  end

  before do
    system("git", "init", "--quiet", "-b", "main", ".")
    system("git", "config", "user.email", "test@test.com")
    system("git", "config", "user.name", "Test")
    system("git", "commit", "--allow-empty", "--quiet", "-m", "init")
  end

  describe "#push" do
    before { allow(origin).to receive(:sh) }

    it "pushes the current branch, then the tag, to the resolved remote", :aggregate_failures do
      origin.push
      expect(origin).to have_received(:sh).with("git", "push", "origin", "refs/heads/main").ordered
      expect(origin).to have_received(:sh).with("git", "push", "origin", "refs/tags/v1.2.3").ordered
    end
  end

  describe "#push against a real remote" do
    before do
      system("git", "clone", "--quiet", "--bare", ".", "origin.git")
      system("git", "remote", "add", "origin", "origin.git")
      system("git", "tag", "v1.2.3")
    end

    it "lands the tag on the remote and stays idempotent on re-run", :aggregate_failures do
      origin.push
      expect(`git --git-dir=origin.git tag`.strip).to eq("v1.2.3")
      expect { described_class.new("v1.2.3").push }.not_to raise_error
    end
  end
end
```

- [ ] **Step 2: Run the spec, verify it fails**

Run: `bundle exec rspec spec/gempilot/origin_spec.rb`
Expected: FAIL — `uninitialized constant Gempilot::Origin` (or `NameError`).

- [ ] **Step 3: Implement `Gempilot::Origin`**

Create `lib/gempilot/origin.rb`:

```ruby
require "open3"

module Gempilot
  ## Pushes the current branch and a release tag to the branch's git remote.
  ## Backs the +release:source_control_push+ task. Idempotent: pushing an
  ## already-pushed branch or tag is a no-op, so re-running a release never
  ## fails on an existing tag (unlike bundler's +already_tagged?+ guard, which
  ## skips the push entirely once the tag exists locally).
  class Origin
    include StrictShell

    attr_reader :tag

    def initialize(tag)
      @tag = tag
    end

    def push
      sh "git", "push", remote, "refs/heads/#{branch}"
      sh "git", "push", remote, "refs/tags/#{tag}"
    end

    private

    def branch
      @branch ||= capture("git", "rev-parse", "--abbrev-ref", "HEAD")
    end

    def remote
      @remote ||= configured_remote || "origin"
    end

    def configured_remote
      out, status = Open3.capture2("git", "config", "--get", "branch.#{branch}.remote")
      out.strip if status.success?
    end

    def capture(*args)
      out, status = Open3.capture2(*args)
      raise "Command #{args.join(" ").inspect} failed" unless status.success?

      out.strip
    end
  end
end
```

- [ ] **Step 4: Run the spec, verify it passes**

Run: `bundle exec rspec spec/gempilot/origin_spec.rb`
Expected: PASS — `3 examples, 0 failures` (2 `#push` examples across the two describe blocks). RuboCop next.

- [ ] **Step 5: Lint the new files**

Run: `bundle exec rubocop lib/gempilot/origin.rb spec/gempilot/origin_spec.rb`
Expected: `no offenses detected`. If any offense appears, fix it and re-run.

- [ ] **Step 6: Commit**

```bash
git add lib/gempilot/origin.rb spec/gempilot/origin_spec.rb
git commit -m "Add Gempilot::Origin for idempotent commit+tag push"
```

---

## Task 2: Slim `GithubRelease#create`

**Files:**
- Modify: `lib/gempilot/github_release.rb`
- Test: `spec/gempilot/github_release_spec.rb`

Pushing is now `Origin`'s job (the `release:source_control_push` prerequisite). `GithubRelease#create` should only call `gh release create`.

- [ ] **Step 1: Update the spec to drop the git-push expectations**

In `spec/gempilot/github_release_spec.rb`, replace the entire `describe "#create"` block:

```ruby
  describe "#create" do
    it "creates a release with generated notes" do
      release.create
      args = ["gh", "release", "create", "--generate-notes", "--fail-on-no-commits", tag]
      expect(release).to have_received(:sh).with(*args)
    end
  end
```

(Leave the `#destroy` and `#list` describe blocks unchanged.)

- [ ] **Step 2: Run the spec, verify `#create` now fails**

Run: `bundle exec rspec spec/gempilot/github_release_spec.rb`
Expected: The `#create` example passes already (it only asserts the `gh` call), but confirm the whole file is green. If green, the current `create` still issues `git push` calls harmlessly. To make the test *drive* the change, also assert no git push:

Add this example inside `describe "#create"`:

```ruby
    it "does not push git refs itself" do
      release.create
      expect(release).not_to have_received(:sh).with("git", any_args)
    end
```

Run again: `bundle exec rspec spec/gempilot/github_release_spec.rb`
Expected: FAIL — `does not push git refs itself` fails because `create` still runs `git push`.

- [ ] **Step 3: Remove the git push from `create`**

In `lib/gempilot/github_release.rb`, change `create` from:

```ruby
    def create
      sh "git", "push"
      sh "git", "push", "--tags"
      sh "gh", "release", "create",
         "--generate-notes", "--fail-on-no-commits",
         tag
    end
```

to:

```ruby
    def create
      sh "gh", "release", "create",
         "--generate-notes", "--fail-on-no-commits",
         tag
    end
```

- [ ] **Step 4: Run the spec, verify it passes**

Run: `bundle exec rspec spec/gempilot/github_release_spec.rb`
Expected: PASS — all examples green.

- [ ] **Step 5: Lint**

Run: `bundle exec rubocop lib/gempilot/github_release.rb spec/gempilot/github_release_spec.rb`
Expected: `no offenses detected`.

- [ ] **Step 6: Commit**

```bash
git add lib/gempilot/github_release.rb spec/gempilot/github_release_spec.rb
git commit -m "Slim GithubRelease#create: push is now Origin's job"
```

---

## Task 3: `ReleaseTasks` module + rewire `VersionTask`

**Files:**
- Create: `lib/gempilot/release_tasks.rb`
- Modify: `lib/gempilot/version_task.rb`
- Test: `spec/gempilot/version_task_spec.rb`

The new `release`/`unrelease` task tree, extracted into a module (keeps `VersionTask` under `Metrics/ClassLength`) and `include`d into `VersionTask`.

- [ ] **Step 1: Write the failing spec additions**

In `spec/gempilot/version_task_spec.rb`, add these two `describe` blocks inside the top-level `RSpec.describe Gempilot::VersionTask do ... end` (e.g. after the existing `describe "version:release"` block, before the final `end`):

```ruby
  describe "release task hierarchy" do
    it "defines the release and unrelease tasks", :aggregate_failures do
      %w[release release:rubygems release:github release:list:github unrelease unrelease:github].each do |name|
        expect(Rake::Task).to be_task_defined(name)
      end
    end

    it "removes the old version:github tasks", :aggregate_failures do
      %w[version:github:release version:github:unrelease version:github:list].each do |name|
        expect(Rake::Task).not_to be_task_defined(name)
      end
    end

    it "composes release from the per-remote tasks" do
      expect(Rake::Task["release"].prerequisites).to eq(%w[release:rubygems release:github])
    end

    it "builds release:rubygems from bundler's own tasks" do
      chain = %w[build release:guard_clean release:source_control_push release:rubygem_push]
      expect(Rake::Task["release:rubygems"].prerequisites).to eq(chain)
    end

    it "composes unrelease from the github task" do
      expect(Rake::Task["unrelease"].prerequisites).to eq(%w[unrelease:github])
    end
  end

  describe "release task behavior" do
    let(:origin) { instance_double(Gempilot::Origin, push: nil) }
    let(:github) { instance_double(Gempilot::GithubRelease, create: nil, destroy: nil, list: nil) }

    before do
      allow(Gempilot::Origin).to receive(:new).and_return(origin)
      allow(Gempilot::GithubRelease).to receive(:new).and_return(github)
    end

    it "release:source_control_push pushes via Origin" do
      Rake::Task["release:source_control_push"].invoke
      expect(origin).to have_received(:push)
    end

    it "release:github pushes, then creates the release", :aggregate_failures do
      Rake::Task["release:github"].invoke
      expect(origin).to have_received(:push)
      expect(github).to have_received(:create)
    end

    it "release:list:github lists releases" do
      Rake::Task["release:list:github"].invoke
      expect(github).to have_received(:list)
    end

    it "unrelease:github destroys the release" do
      Rake::Task["unrelease:github"].invoke
      expect(github).to have_received(:destroy)
    end
  end
```

- [ ] **Step 2: Run the spec, verify it fails**

Run: `bundle exec rspec spec/gempilot/version_task_spec.rb`
Expected: FAIL — `release`/`release:github`/etc. are not defined; several examples error with "Don't know how to build task 'release:github'" / `be_task_defined` returns false.

- [ ] **Step 3: Create the `ReleaseTasks` module**

Create `lib/gempilot/release_tasks.rb`:

```ruby
module Gempilot
  ## Rake task definitions for publishing a release to RubyGems and GitHub.
  ## Mixed into VersionTask. Assumes +bundler/gem_tasks+ has been required so the
  ## +build+, +release:guard_clean+, and +release:rubygem_push+ tasks exist (the
  ## generated Rakefile guarantees this). Fixes GitHub releasing by replacing
  ## bundler's +already_tagged?+-guarded +release:source_control_push+ with an
  ## idempotent push.
  module ReleaseTasks
    private

    def define_release_tasks(project)
      override_source_control_push(project)
      define_release_namespace(project)
      define_root_release_task
      define_unrelease_tasks(project)
    end

    def override_source_control_push(project)
      clear_task "release:source_control_push"
      task("release:source_control_push") { Origin.new(project.version_tag).push }
    end

    def define_release_namespace(project)
      namespace :release do
        define_rubygems_release
        define_github_release(project)
        define_release_list(project)
      end
    end

    def define_rubygems_release
      desc "Release the current version to RubyGems"
      task rubygems: %w[build release:guard_clean release:source_control_push release:rubygem_push]
    end

    def define_github_release(project)
      desc "Create a GitHub release for the current version"
      task github: "release:source_control_push" do
        GithubRelease.new(project.version_tag).create
      end
    end

    def define_release_list(project)
      namespace :list do
        desc "List GitHub releases"
        task(:github) { GithubRelease.new(project.version_tag).list }
      end
    end

    def define_root_release_task
      clear_task "release"
      desc "Release the current version to all remotes"
      task release: %w[release:rubygems release:github]
    end

    def define_unrelease_tasks(project)
      desc "Delete the current release from all remotes that support it"
      task unrelease: %w[unrelease:github]
      define_unrelease_namespace(project)
    end

    def define_unrelease_namespace(project)
      namespace :unrelease do
        desc "Delete the GitHub release for the current version"
        task(:github) { GithubRelease.new(project.version_tag).destroy }
      end
    end

    def clear_task(name)
      Rake::Task[name].clear if Rake::Task.task_defined?(name)
    end
  end
end
```

- [ ] **Step 4: Rewire `VersionTask` to use the module**

In `lib/gempilot/version_task.rb`:

First, add the include at the top of the class body (right after `class VersionTask < Rake::TaskLib`):

```ruby
  class VersionTask < Rake::TaskLib
    include ReleaseTasks

    attr_reader :project
```

Then change `define_tasks` from:

```ruby
    def define_tasks
      define_version_tasks
      define_version_composite_tasks
      define_github_tasks
    end
```

to:

```ruby
    def define_tasks
      define_version_tasks
      define_version_composite_tasks
      define_release_tasks(@project)
    end
```

Then delete the entire `define_github_tasks` method (the `namespace "version:github" do ... end` method) — from `def define_github_tasks` through its closing `end`.

- [ ] **Step 5: Run the version_task spec, verify it passes**

Run: `bundle exec rspec spec/gempilot/version_task_spec.rb`
Expected: PASS — all examples green (existing `version:bump`/`version:release` plus the new hierarchy/behavior examples).

- [ ] **Step 6: Run the full suite + lint**

Run: `bundle exec rake spec && bundle exec rake test && bundle exec rubocop`
Expected: `rake spec` green, `rake test` green, RuboCop `no offenses detected`. In particular confirm `lib/gempilot/version_task.rb` reports no `Metrics/ClassLength` offense.

- [ ] **Step 7: Sanity-check the task tree renders and old tasks are gone**

Run (from the repo root — gempilot dogfoods its own `VersionTask`):
```bash
bundle exec rake -T release ; bundle exec rake -T unrelease ; bundle exec rake -AT | grep -c 'version:github' || true
```
Expected: `release`, `release:rubygems`, `release:github`, `release:list:github`, `unrelease`, `unrelease:github` appear; the `version:github` grep count is `0`.

- [ ] **Step 8: Commit**

```bash
git add lib/gempilot/release_tasks.rb lib/gempilot/version_task.rb spec/gempilot/version_task_spec.rb
git commit -m "Move GitHub publishing into idiomatic release/unrelease namespace"
```

---

## Task 4: Update docs

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`

No tests — documentation only. Make the exact edits below.

- [ ] **Step 1: Update the README `gempilot release` note**

In `README.md`, replace:

```markdown
Delegates to `rake release` to build and push the gem.
```

with:

```markdown
Delegates to `rake release`, which publishes the current version to all remotes
(RubyGems + GitHub).
```

- [ ] **Step 2: Update the README task table**

In `README.md`, replace these three rows:

```markdown
| `rake version:github:release` | Push and create a GitHub release |
| `rake version:github:unrelease` | Delete the GitHub release |
| `rake version:github:list` | List GitHub releases |
```

with:

```markdown
| `rake release` | Publish the current version to all remotes (RubyGems + GitHub) |
| `rake release:rubygems` | Build and push the gem to RubyGems |
| `rake release:github` | Push commit + tag, then create the GitHub release |
| `rake release:list:github` | List GitHub releases |
| `rake unrelease` | Delete the release from all remotes that support it |
| `rake unrelease:github` | Delete the GitHub release and remote tag |
```

(The `rake version:release` and `rake version:unrelease` rows stay.)

- [ ] **Step 3: Update CLAUDE.md**

In `CLAUDE.md`, replace this bullet:

```markdown
- Version lifecycle rake tasks installed via `Gempilot::VersionTask.new` (a `Rake::TaskLib`): `version:current/bump/commit/tag/untag/reset/revert`, composite `version:release`/`version:unrelease`, and `version:github:release/unrelease/list`
```

with:

```markdown
- Version lifecycle rake tasks installed via `Gempilot::VersionTask.new` (a `Rake::TaskLib`): `version:current/bump/commit/tag/untag/reset/revert` and composite `version:release`/`version:unrelease`
- Publishing rake tasks (mixed into `VersionTask` via `Gempilot::ReleaseTasks`): `release` (all remotes), `release:rubygems`, `release:github`, `release:list:github`, `unrelease`, `unrelease:github`. These override and reuse bundler's `bundler/gem_tasks` release chain; `release:source_control_push` is replaced with `Gempilot::Origin` to push commit+tag idempotently
```

- [ ] **Step 4: Verify no stale references remain**

Run: `grep -rn "version:github" README.md CLAUDE.md`
Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add README.md CLAUDE.md docs/superpowers/specs/2026-07-20-release-task-hierarchy-design.md
git commit -m "Docs: document release/unrelease task hierarchy"
```

---

## Task 5: Full verification

**Files:** none (verification only).

- [ ] **Step 1: Run the complete default suite**

Run: `bundle exec rake`
Expected: `task default: [:test, :spec, :rubocop]` runs all three — Minitest green (`0 failures`), RSpec green (`0 failures`), RuboCop `no offenses detected`.

- [ ] **Step 2: Verify Zeitwerk naming for the new files**

Run: `bundle exec rake zeitwerk:validate`
Expected: `Zeitwerk: All files loaded successfully.` (confirms `lib/gempilot/origin.rb` → `Gempilot::Origin` and `lib/gempilot/release_tasks.rb` → `Gempilot::ReleaseTasks` load cleanly under eager load).

- [ ] **Step 3: Confirm the working tree is clean and review the branch**

Run: `git status` and `git log --oneline master..HEAD`
Expected: clean working tree; commits for Origin, GithubRelease slim, release/unrelease move, and docs.

---

## Self-review notes (traceability to spec)

- **Task hierarchy** (spec §"Task interface"/"Task definitions") → Task 3 (module + rewire) + Task 3 Step 1 structure specs.
- **Bug fix — idempotent push replacing `already_tagged?`** (spec §"Problem"/`Origin`) → Task 1 (`Origin`, incl. real-remote idempotency regression test) + Task 3 `override_source_control_push`.
- **`GithubRelease` slimmed** (spec §"Components") → Task 2.
- **RubyGems reuses bundler leaf tasks** (spec §"Decisions") → Task 3 `define_rubygems_release` + prerequisite spec.
- **`unrelease:rubygems` errors naturally** (spec §"Error handling") → covered by not defining it; documented, no code.
- **Docs** (spec §"Docs") → Task 4.
- **`Rakefile.erb` unchanged** (spec §"Out of scope") → no task; load order already correct.
