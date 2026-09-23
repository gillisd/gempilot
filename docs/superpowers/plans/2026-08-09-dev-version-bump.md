# Forward-Moving Version Bumps Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every `version:bump` segment move strictly forward under RubyGems ordering, add a `tiny` fourth-integer segment, and mark dev GitHub releases as prereleases.

**Architecture:** A new `Gempilot::SegmentedVersion` value object (Data class) owns parsing of the three accepted version shapes (`M.m.p`, `M.m.p.N`, `M.m.p.devN`) and all bump arithmetic; `Project::Version#bump` becomes a thin delegation, keeping its `Data.define(:path, :value)` surface untouched. `GithubRelease#create` derives prerelease status from its tag string. Spec: `docs/superpowers/specs/2026-08-09-dev-version-bump-design.md`.

**Tech Stack:** Ruby (Zeitwerk autoloading), RSpec (`spec/`, library), Minitest (`test/`, CLI), RuboCop.

## Global Constraints

- Semantics rule (from spec): every bump yields the smallest version of the requested shape strictly greater than the current version. Full transition table is in the spec and is reproduced in Task 1's test code — treat that table as normative.
- Double-quoted strings (`Style/StringLiterals: double_quotes`); NO `# frozen_string_literal:` comments (`EnforcedStyle: never`); trailing commas in multiline literals/arguments.
- Ruby ≥ 3.4 idioms are fine (`it` block parameter is used throughout the codebase); rdoc `##` doc blocks (never YARD tags), no blank line between `##` block and the definition.
- Zeitwerk: new file `lib/gempilot/segmented_version.rb` MUST define `Gempilot::SegmentedVersion` (the eager-load spec `spec/zeitwerk_spec.rb` enforces this).
- Verification commands: `bundle exec rspec <file>` for focused runs, `bundle exec rake default` (= `test` + `spec` + `rubocop`) for the full gate. Baseline before Task 1: 145 examples, 0 failures, 60 files no rubocop offenses.
- Commit messages: plain imperative, no conventional-commit prefixes (repo style: "Add issue", "Add dev version bump design spec").

---

### Task 1: SegmentedVersion arithmetic + Version#bump rewrite

**Files:**
- Create: `lib/gempilot/segmented_version.rb`
- Modify: `lib/gempilot/project/version.rb` (full rewrite shown below)
- Test: `spec/gempilot/project/version_spec.rb` (full rewrite shown below)
- Test: `spec/gempilot/version_task_spec.rb:35-38` (one expectation flip)

**Interfaces:**
- Consumes: `Gempilot::Project::Version` `Data.define(:path, :value)` (existing), `Data#with` (Ruby core).
- Produces: `Gempilot::SegmentedVersion.parse(string) → SegmentedVersion` (raises `ArgumentError` on unrecognized shapes), `SegmentedVersion#bump(segment) → SegmentedVersion` for `:major/:minor/:patch/:tiny/:dev` (symbol or string; raises `ArgumentError` otherwise), `SegmentedVersion#to_s → String`. `Version#bump(segment = :patch)` / `#next_version` keep their existing signatures — later tasks rely only on those.

- [ ] **Step 1: Rewrite the version spec with the normative transition table**

Replace the entire contents of `spec/gempilot/project/version_spec.rb` with:

```ruby
require "spec_helper"

RSpec.describe Gempilot::Project::Version do
  let(:path) { Pathname("lib/my_gem/version.rb") }

  def version(value)
    described_class.new(path: path, value: value)
  end

  describe "#tag" do
    it "prepends v to the value" do
      expect(version("1.2.3").tag).to eq("v1.2.3")
    end
  end

  describe "#bump" do
    transitions = {
      "1.2.3" => { major: "2.0.0", minor: "1.3.0", patch: "1.2.4", tiny: "1.2.3.1", dev: "1.2.4.dev1" },
      "1.2.3.1" => { major: "2.0.0", minor: "1.3.0", patch: "1.2.4", tiny: "1.2.3.2", dev: "1.2.4.dev1" },
      "1.2.4.dev2" => { major: "2.0.0", minor: "1.3.0", patch: "1.2.4", tiny: "1.2.4.1", dev: "1.2.4.dev3" },
      "1.3.0.dev2" => { major: "2.0.0", minor: "1.3.0", patch: "1.3.0", tiny: "1.3.0.1", dev: "1.3.0.dev3" },
      "2.0.0.dev2" => { major: "2.0.0", minor: "2.0.0", patch: "2.0.0", tiny: "2.0.0.1", dev: "2.0.0.dev3" },
    }

    transitions.each do |from, bumps|
      bumps.each do |segment, to|
        it "bumps #{from} to #{to} for #{segment}" do
          expect(version(from).bump(segment).value).to eq(to)
        end
      end
    end

    it "moves every transition strictly forward under Gem::Version ordering" do
      transitions.each do |from, bumps|
        bumps.each_value do |to|
          expect(Gem::Version.new(to)).to be > Gem::Version.new(from)
        end
      end
    end

    it "bumps patch by default" do
      expect(version("1.2.3").bump.value).to eq("1.2.4")
    end

    it "accepts segment as a string" do
      expect(version("1.0.0").bump("minor").value).to eq("1.1.0")
    end

    it "raises for an unknown segment" do
      expect { version("1.0.0").bump(:hotfix) }.to raise_error(ArgumentError, /unknown segment/i)
    end

    it "raises for a two-integer version" do
      expect { version("1.2").bump }.to raise_error(ArgumentError, /cannot parse/i)
    end

    it "raises for a non-dev prerelease version" do
      expect { version("1.2.3.beta1").bump }.to raise_error(ArgumentError, /cannot parse/i)
    end
  end

  describe "#next_version" do
    it "finalizes a dev version to its target" do
      expect(version("0.0.4.dev3").next_version.value).to eq("0.0.4")
    end

    it "bumps the patch of a release version" do
      expect(version("1.0.99").next_version.value).to eq("1.0.100")
    end
  end
end
```

- [ ] **Step 2: Flip the stale expectation in the version task spec**

In `spec/gempilot/version_task_spec.rb`, the fixture version is `1.0.0.dev3`. Change the `version:bump` default example (currently expects `"1.0.1"`) to:

```ruby
    it "finalizes a dev version to its target by default" do
      Rake::Task["version:bump"].invoke
      expect(version_in_file).to eq("1.0.0")
    end
```

(The `version:bump[dev]` → `"1.0.0.dev4"` and both `version:release` examples are already correct under the new semantics — do not touch them.)

- [ ] **Step 3: Run the specs to verify they fail for the right reason**

Run: `bundle exec rspec spec/gempilot/project/version_spec.rb spec/gempilot/version_task_spec.rb --no-color`
Expected: FAILURES including `expected: "1.2.4.dev1" got: "1.2.3.dev1"` (dev goes backward today), `expected: "1.2.4" got: "1.2.5"` (patch overshoots a dev target), every `:tiny` cell erroring with `ArgumentError: Unknown segment :tiny` (old code rejects the segment), the `"1.2"` example failing with `NoMethodError` instead of `ArgumentError` (old code coerces then crashes on the missing patch integer), the `"1.2.3.beta1"` example failing with "expected ArgumentError but nothing was raised" (old code silently coerces to `1.2.4`), and `expected: "1.0.0" got: "1.0.1"` in the task spec. The `#tag`, string-segment, and unknown-segment examples still pass.

- [ ] **Step 4: Create the SegmentedVersion value object**

Create `lib/gempilot/segmented_version.rb`:

```ruby
module Gempilot
  ## Arithmetic over the three version shapes gempilot accepts: release
  ## (+1.2.3+), tiny release (+1.2.3.1+), and dev prerelease (+1.2.3.dev1+).
  ##
  ## Every bump returns the smallest version of the requested shape that is
  ## strictly greater than the current version under RubyGems ordering, so
  ## bumping always moves a project forward: a dev bump previews the next
  ## patch (+1.2.3+ to +1.2.4.dev1+) and numeric bumps finalize a dev cycle
  ## (+1.2.4.dev2+ to +1.2.4+ for +:patch+).
  SegmentedVersion = Data.define(:major, :minor, :patch, :tiny, :dev) do
    def self.parse(string)
      format = /\A(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)(?:\.(?<tiny>\d+)|\.dev(?<dev>\d+))?\z/
      match = format.match(string)
      raise ArgumentError, "cannot parse version: #{string.inspect}" unless match

      new(**match.named_captures.to_h { |name, digits| [name.to_sym, digits&.to_i] })
    end

    def bump(segment)
      case segment.to_sym
      when :major then bump_major
      when :minor then bump_minor
      when :patch then bump_patch
      when :tiny  then bump_tiny
      when :dev   then bump_dev
      else raise ArgumentError, "Unknown segment #{segment.inspect}. Use :major, :minor, :patch, :tiny, or :dev"
      end
    end

    def to_s
      [major, minor, patch, tiny, ("dev#{dev}" if dev)].compact.join(".")
    end

    private

    def bump_major
      return finalize if dev && minor.zero? && patch.zero?

      with(major: major + 1, minor: 0, patch: 0, tiny: nil, dev: nil)
    end

    def bump_minor
      return finalize if dev && patch.zero?

      with(minor: minor + 1, patch: 0, tiny: nil, dev: nil)
    end

    def bump_patch
      dev ? finalize : with(patch: patch + 1, tiny: nil)
    end

    def bump_tiny
      with(tiny: (tiny || 0) + 1, dev: nil)
    end

    def bump_dev
      dev ? with(dev: dev + 1) : with(patch: patch + 1, tiny: nil, dev: 1)
    end

    def finalize
      with(tiny: nil, dev: nil)
    end
  end.freeze
end
```

Notes for the implementer:
- The regex lives in a method-local (`format`), not a constant — a constant inside the `Data.define` block would trip `Lint/ConstantDefinitionInBlock`.
- `bump` dispatches to five one-branch private methods to stay under `Metrics/CyclomaticComplexity` (max 7).
- `finalize` drops the prerelease/tiny suffix — it encodes "the smallest version of a numeric shape greater than a dev version is the dev version's own target".

- [ ] **Step 5: Rewrite Version#bump as a delegation**

Replace the entire contents of `lib/gempilot/project/version.rb` with:

```ruby
module Gempilot
  class Project
    ## The project's version file (+path+) and value. Bump arithmetic
    ## delegates to SegmentedVersion, so every bump moves strictly forward
    ## under RubyGems ordering.
    Version = Data.define(:path, :value) do
      def tag
        "v#{value}"
      end

      def bump(segment = :patch)
        with(value: SegmentedVersion.parse(value).bump(segment).to_s)
      end

      alias_method :next_version, :bump
    end.freeze
  end
end
```

- [ ] **Step 6: Run the specs to verify they pass**

Run: `bundle exec rspec spec/gempilot/project/version_spec.rb spec/gempilot/version_task_spec.rb --no-color`
Expected: PASS, 0 failures (34 + task-spec examples). If `zeitwerk` cannot resolve the new constant, the filename does not match `Gempilot::SegmentedVersion` — fix the filename, not the loader.

- [ ] **Step 7: Run the full gate**

Run: `bundle exec rake default 2>&1 | tail -8`
Expected: minitest green, all RSpec examples green (count grows from 145), `no offenses detected`.

- [ ] **Step 8: Commit**

```bash
git add lib/gempilot/segmented_version.rb lib/gempilot/project/version.rb spec/gempilot/project/version_spec.rb spec/gempilot/version_task_spec.rb
git commit -m "Make version bumps move strictly forward"
```

---

### Task 2: `tiny` segment on the rake and CLI surfaces

**Files:**
- Modify: `lib/gempilot/version_task.rb:53` (desc string only)
- Modify: `lib/gempilot/cli/commands/bump.rb`
- Test: `spec/gempilot/version_task_spec.rb` (add one example)
- Test: `test/gempilot/cli/bump_command_test.rb` (add one test)

**Interfaces:**
- Consumes: `Version#bump` accepting `:tiny` (Task 1); rake `version:bump[segment]` forwards the segment string verbatim (existing behavior — no logic change needed there).
- Produces: `gempilot bump tiny` and `rake version:bump[tiny]` as documented user commands; CLI allowed-segment list `%w[patch minor major tiny dev]`.

- [ ] **Step 1: Add the failing rake-task example**

In `spec/gempilot/version_task_spec.rb`, inside `describe "version:bump"`, add:

```ruby
    it "bumps the tiny segment" do
      Rake::Task["version:bump"].invoke("tiny")
      expect(version_in_file).to eq("1.0.0.1")
    end
```

(Fixture is `1.0.0.dev3`; `tiny` finalizes the core and appends `.1`.)

- [ ] **Step 2: Add the failing CLI test**

In `test/gempilot/cli/bump_command_test.rb`, after `test_bump_dev_invokes_rake`, add:

```ruby
      def test_bump_tiny_invokes_rake
        calls = recorded_system_calls { |cmd| cmd.main(["tiny"]) }

        assert_includes calls, ["bundle", "exec", "rake", "version:bump[tiny]"]
      end
```

- [ ] **Step 3: Run both to verify the CLI test fails and the rake example passes**

Run: `bundle exec rspec spec/gempilot/version_task_spec.rb --no-color && bundle exec rake test 2>&1 | tail -4`
Expected: the rake-task example PASSES already (the task forwards any segment and Task 1 taught `Version#bump` about `:tiny`) — it is a pin, not a driver. The minitest CLI test FAILS: `Bump#validate_segment` rejects `tiny` and exits 1 before calling rake.

- [ ] **Step 4: Teach the CLI command the tiny segment**

In `lib/gempilot/cli/commands/bump.rb` apply these four edits:

```ruby
        description "Bump the gem version (patch by default, or minor/major/tiny/dev)"

        examples [
          "",
          "patch",
          "minor",
          "major",
          "tiny",
          "dev",
        ]

        argument :segment, required: false,
                           desc: "Version segment to bump: patch (default), minor, major, tiny, or dev"
```

and in `validate_segment`:

```ruby
          return segment if %w[patch minor major tiny dev].include?(segment)

          puts colors.red("Unknown segment '#{segment}'. Use patch, minor, major, tiny, or dev.")
```

- [ ] **Step 5: Update the rake task description**

In `lib/gempilot/version_task.rb`, `define_bump_task`:

```ruby
      desc "Bump version (patch default; segments: major, minor, patch, tiny, dev)"
```

- [ ] **Step 6: Run the full gate**

Run: `bundle exec rake default 2>&1 | tail -8`
Expected: all green, no offenses. (`test_bump_fails_with_invalid_segment` uses `hotfix`, which stays invalid.)

- [ ] **Step 7: Commit**

```bash
git add lib/gempilot/version_task.rb lib/gempilot/cli/commands/bump.rb spec/gempilot/version_task_spec.rb test/gempilot/cli/bump_command_test.rb
git commit -m "Add tiny segment to bump interfaces"
```

---

### Task 3: Mark dev GitHub releases as prereleases

**Files:**
- Modify: `lib/gempilot/github_release.rb`
- Test: `spec/gempilot/github_release_spec.rb`

**Interfaces:**
- Consumes: `GithubRelease.new(tag)` with tag strings like `"v1.2.4.dev1"` (signature unchanged); `Gem::Version#prerelease?` (rubygems, always loaded).
- Produces: `gh release create` invoked with `--prerelease` when and only when the tag names a prerelease version.

- [ ] **Step 1: Add the failing specs**

In `spec/gempilot/github_release_spec.rb`, inside `describe "#create"`, add two contexts after the existing examples:

```ruby
    context "with a dev prerelease tag" do
      let(:tag) { "v1.2.4.dev1" }

      it "marks the release as a prerelease" do
        release.create
        args = ["gh", "release", "create", "--generate-notes", "--fail-on-no-commits", "--prerelease", tag]
        expect(release).to have_received(:sh).with(*args)
      end
    end

    context "with a tiny release tag" do
      let(:tag) { "v1.2.3.1" }

      it "does not mark the release as a prerelease" do
        release.create
        args = ["gh", "release", "create", "--generate-notes", "--fail-on-no-commits", tag]
        expect(release).to have_received(:sh).with(*args)
      end
    end
```

- [ ] **Step 2: Run to verify the dev context fails**

Run: `bundle exec rspec spec/gempilot/github_release_spec.rb --no-color`
Expected: FAIL — the dev-tag example receives no `--prerelease` argument; the tiny-tag example passes.

- [ ] **Step 3: Implement the prerelease flag**

In `lib/gempilot/github_release.rb`, replace `#create` and append a private section after `#list`:

```ruby
    def create
      sh "gh", "release", "create",
         "--generate-notes", "--fail-on-no-commits",
         *prerelease_flag,
         tag
    end
```

```ruby
    private

    def prerelease_flag
      Gem::Version.new(tag.delete_prefix("v")).prerelease? ? ["--prerelease"] : []
    end
```

Also extend the class doc block's first line to:

```ruby
  ## Manages GitHub releases for a version tag. Tags naming a prerelease
  ## version (e.g. +v1.2.4.dev1+) are created as GitHub prereleases.
```

- [ ] **Step 4: Run the spec, then the full gate**

Run: `bundle exec rspec spec/gempilot/github_release_spec.rb --no-color && bundle exec rake default 2>&1 | tail -8`
Expected: PASS everywhere, no offenses.

- [ ] **Step 5: Commit**

```bash
git add lib/gempilot/github_release.rb spec/gempilot/github_release_spec.rb
git commit -m "Mark dev GitHub releases as prereleases"
```

---

### Task 4: Documentation

**Files:**
- Modify: `README.md` (bump section ~line 77-85; version tasks table row ~line 116)
- Modify: `CLAUDE.md` (bump command bullet; architecture list)

**Interfaces:**
- Consumes: final semantics from Tasks 1-3.
- Produces: user-facing docs; no code.

- [ ] **Step 1: Update the README bump section**

Replace the `gempilot bump` code block and add one paragraph after it:

````markdown
```bash
gempilot bump          # patch (default)
gempilot bump minor
gempilot bump major
gempilot bump tiny     # fourth integer for tiny follow-ups: 0.2.0 -> 0.2.0.1
gempilot bump dev      # preview of the next patch: 0.2.0 -> 0.2.1.dev1
```

A `dev` version previews the next patch, so it always sorts ahead of the
current release (`0.2.0 < 0.2.1.dev1 < 0.2.1`), and a numeric bump finalizes
the cycle (`gempilot bump` from `0.2.1.dev3` gives `0.2.1`). A repo holding an
old-style dev version — one created *after* its base version shipped — needs a
one-time hand edit of `version.rb` past the last published version.
````

- [ ] **Step 2: Update the README version tasks table row**

```markdown
| `rake version:bump` | Bump the version (patch default; major/minor/patch/tiny/dev) |
```

- [ ] **Step 3: Update CLAUDE.md**

Change the bump command bullet to:

```markdown
- `gempilot bump` — Bump version in `version.rb` (patch default, or minor/major/tiny/dev)
```

and add to the Architecture list, after the `GemConstant` bullet:

```markdown
- `SegmentedVersion` value object (`lib/gempilot/segmented_version.rb`) owns version parsing and bump arithmetic; every bump moves to the smallest version of the requested shape greater than the current version (RubyGems ordering)
```

- [ ] **Step 4: Full gate and commit**

Run: `bundle exec rake default 2>&1 | tail -8`
Expected: all green (docs only — this is a regression guard).

```bash
git add README.md CLAUDE.md
git commit -m "Update docs for forward-moving version bumps"
```
