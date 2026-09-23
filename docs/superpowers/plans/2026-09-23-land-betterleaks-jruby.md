# Land the betterleaks-jruby Branch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring `origin/betterleaks-jruby` — which already implements issues `986E0100` (MRI-only dev gems) and `3FFE7616` (betterleaks integration), with its own approved design spec and plan committed on the branch — onto today's master, and get it merged. Nothing is re-planned here; the feature work is done.

**Architecture:** The branch is 10 commits from 2026-07-26 (design spec, plan, `platforms :mri` block in gempilot's Gemfile, `Gempilot::BetterleaksTask`, hook and `secrets.yml` templates, `--[no-]betterleaks` on `create`, a `gempilot setup betterleaks` retrofit command, dogfooding, issue closures) plus one Aug 7 commit filing issue `F7C6A9AA`. Master moved since (dev-version-bump merge, the `json` pin), so merging master into the branch produces exactly one conflict (`CLAUDE.md`; `issues.rec` auto-merges), and master's own `json`-ordering regression must be fixed for the gate to go green. The branch's published history is never rewritten and nothing in this plan pushes. Verified 2026-09-23 in a scratch copy: after the merge, that one-line fix, and Task 3, the full gate is `122 runs, 0 failures`, `205 examples, 0 failures`, `69 files inspected, no offenses`.

**Tech Stack:** git rebase, GNU recutils (`recset`, `recsel`, `recfix`) for `issues.rec`, `bundle exec rake default`.

**Issues:** `986E0100-88F4-11F1-B718-FE6CB9572C2D`, `3FFE7616-88F5-11F1-8D3B-FE6CB9572C2D` (both closed by the branch's own `issues.rec` commit).

## Global Constraints

- Do not redesign anything on the branch; its spec (`docs/superpowers/specs/2026-07-26-betterleaks-and-jruby-design.md` on the branch) is marked approved. Notable decisions it made: the hook and `rake betterleaks` skip with an install hint when the binary is missing (fail open; CI enforces), CI is a separate `secrets.yml` using `go install github.com/betterleaks/betterleaks@latest`, and Issue A scopes `platforms :mri` to gempilot's own Gemfile only.
- Master's uncommitted working-tree change to `issues.rec` (closing `2360FFA4`) is separate from this branch; commit it on master before or after, never inside the rebase.
- Commit messages: plain imperative sentences, no conventional-commit prefixes.
- `bundle install` cannot materialize master's lockfile on machines without the author's vault (rake 13.4.3); run the gate where the bundle already works.

---

### Task 1: Restore alphabetical order in the Gemfile template

**Files:**
- Modify: `data/templates/gem/Gemfile.erb:5-7`

**Interfaces:**
- Produces: a template whose `gem` lines are sorted; four master tests go green (`test_gemfile_gems_are_alphabetically_ordered`, its rspec twin, and both `*_default_rake_task_passes` integration tests, which fail today because the generated gem's RuboCop reports `Gemfile:6 Bundler/OrderedGems`).

- [ ] **Step 1: See the failures on master**

Run: `bundle exec ruby -Itest -Ilib test/gempilot/cli/create_command_test.rb -n "/gemfile/i"`
Expected: `4 runs, ... 2 failures`, actual list starting `["json", "gempilot", "irb", ...]`.

- [ ] **Step 2: Move the json line**

Replace the top of `data/templates/gem/Gemfile.erb` (everything above the first `<% if` line) with:

```erb
source "https://rubygems.org"

gemspec

gem "gempilot", require: false
gem "irb"
gem "json", "~> 2.21" # temporary json 3.0.0 is currently breaking everything
```

- [ ] **Step 3: Verify and commit on master**

Run: `bundle exec ruby -Itest -Ilib test/gempilot/cli/create_command_test.rb`
Expected: `53 runs, 0 failures`.

```bash
git add data/templates/gem/Gemfile.erb
git commit -m "Restore alphabetical order in the Gemfile template"
```

(Open this as its own one-commit PR, or fold it in as the first commit of the rebased branch; either way it must precede Task 3's gate.)

---

### Task 2: Merge master into the branch

No rebase and no force-push: the branch's published history stays as it is, master is merged in, and the merge commit is what gets pushed later, normally.

**Files:**
- Conflict to resolve: `CLAUDE.md` (once). `issues.rec` auto-merges.

**Interfaces:**
- Consumes: `origin/betterleaks-jruby`, master with Task 1.
- Produces: local branch `betterleaks-jruby` = its 11 commits + one merge commit, no conflict markers, `recfix` clean.

- [ ] **Step 1: Start the merge**

```bash
git fetch origin
git checkout betterleaks-jruby
git merge master
```

Expected: `Auto-merging issues.rec` succeeds; `Automatic merge failed` only because of `CLAUDE.md` (`git diff --name-only --diff-filter=U` prints exactly `CLAUDE.md`).

- [ ] **Step 2: Check the auto-merged issues.rec**

```bash
recfix issues.rec
recsel -e "Status = 'open'" -P Id issues.rec
```

Expected: `recfix` is silent; the open list no longer contains `986E0100` or `3FFE7616` and does contain `F7C6A9AA` (the branch's new issue, "gempilot new class WebSocket::Server should respect zeitwerk inflectors if present") alongside master's issues.

- [ ] **Step 3: Resolve CLAUDE.md**

The conflict is the Commands list. Keep master's `gempilot bump` line (it mentions `tiny/dev`; the branch's copy is stale) and the branch's new `gempilot setup` line, so the resolved lines read:

```markdown
- `gempilot setup` — Retrofit an integration (e.g. betterleaks) into an existing gem
- `gempilot bump` — Bump version in `version.rb` (patch default, or minor/major/tiny/dev)
```

Remove the conflict markers and the stale `(patch default, or minor/major)` line. `grep -c "gempilot bump" CLAUDE.md` must print `1`.

- [ ] **Step 4: Commit the merge**

```bash
git add CLAUDE.md
git commit -m "Merge master into betterleaks-jruby"
```

Expected: `git log --oneline master..HEAD | wc -l` prints `12` (11 branch commits + the merge); `git diff master -- CLAUDE.md issues.rec` shows only the `gempilot setup` bullet and the branch's Generated Gem Features additions, the two status flips, and the `F7C6A9AA` record.

---

### Task 3: Port three mechanics from the September spike

The branch's design stands. Three details verified in the September rework are strictly better and small enough to land in the same PR (verified 2026-09-23 on the rebased branch: gate `122 runs`, `205 examples`, `69 files`, all green):

1. `rake betterleaks` runs `betterleaks git` unconditionally, so in a gem scaffolded with `--no-git` it dies with `fatal: not a git repository`. Fall back to `betterleaks dir` outside a work tree, and pass `--no-banner`.
2. `secrets.yml` compiles betterleaks from source on every CI run (`actions/setup-go` + `go install ...@latest`, a floating version). Install the pinned 1.8.1 release tarball and verify it against the release's `checksums.txt` instead (download + checksum verified locally; the linux_x64 binary runs on GitHub's ubuntu runners).
3. The task spec only covers the "not installed" skip path. Add real-scan examples: a clean history passes, a randomly generated GitHub token fails the task, and a non-git directory scans without crashing.

**Files:**
- Modify: `lib/gempilot/betterleaks_task.rb`
- Modify: `data/templates/gem/dotfiles/github/workflows/secrets.yml`, `.github/workflows/secrets.yml`
- Test: `spec/gempilot/betterleaks_task_spec.rb`

**Interfaces:**
- Consumes: `Gempilot::BetterleaksTask` as defined on the branch (`task :betterleaks`, `warn_missing`).
- Produces: the same task name; `scan` chooses `git` or `dir` mode; both workflow files share one install step.

- [ ] **Step 1: Add the failing spec examples**

In `spec/gempilot/betterleaks_task_spec.rb` add `require "securerandom"` after `require "spec_helper"`, and before the file's final `end` add:

```ruby
  describe "a real scan" do
    around { |example| Dir.mktmpdir("betterleaks_task_spec") { |dir| Dir.chdir(dir) { example.run } } }

    before { skip "betterleaks is not installed" unless system("betterleaks", "version", out: File::NULL) }

    def commit_file(name, content)
      system("git", "init", "--quiet", "-b", "main", ".")
      system("git", "config", "user.email", "test@test.com")
      system("git", "config", "user.name", "Test")
      File.write(name, content)
      system("git", "add", name)
      system("git", "commit", "--quiet", "-m", "Add #{name}")
    end

    it "passes on a history without secrets" do
      commit_file("app.rb", "puts 'hi'\n")
      expect { Rake::Task["betterleaks"].invoke }.not_to raise_error
    end

    it "fails when the history contains a secret" do
      commit_file("config.rb", %(github_token = "ghp_#{SecureRandom.alphanumeric(36)}"\n))
      expect { Rake::Task["betterleaks"].invoke }.to raise_error(RuntimeError, /betterleaks/)
    end

    it "scans the working tree when the gem is not a git repository" do
      File.write("app.rb", "puts 'hi'\n")
      expect { Rake::Task["betterleaks"].invoke }.not_to raise_error
    end
  end
```

(The token is random on purpose: betterleaks filters keyboard-walk "example" strings, so a fixed fake key is not detected.)

- [ ] **Step 2: Run it to verify the last example fails**

Run: `bundle exec rspec spec/gempilot/betterleaks_task_spec.rb --no-color`
Expected: `5 examples, 1 failure` — "scans the working tree when the gem is not a git repository" raises `Command failed with status (1)` because `betterleaks git` errors outside a repository; the secret example already fails the task as expected.

- [ ] **Step 3: Choose the scan mode**

In `lib/gempilot/betterleaks_task.rb` replace `scan` and `betterleaks_available?` with:

```ruby
    def scan
      return warn_missing unless betterleaks_available?

      sh "betterleaks", mode, "--no-banner", "--redact", "--verbose", "."
    end

    # git mode walks the whole commit history; outside a work tree (a gem
    # scaffolded with --no-git) dir mode scans the files on disk instead of
    # failing on the missing repository.
    def mode
      git_work_tree? ? "git" : "dir"
    end

    def git_work_tree?
      system("git", "rev-parse", "--is-inside-work-tree", out: File::NULL, err: File::NULL)
    end

    def betterleaks_available?
      ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |dir|
        binary = File.join(dir, "betterleaks")
        File.file?(binary) && File.executable?(binary)
      end
    end
```

- [ ] **Step 4: Pin the CI install**

In both `data/templates/gem/dotfiles/github/workflows/secrets.yml` and `.github/workflows/secrets.yml`, replace the three steps `Set up Go`, `Install betterleaks`, `Scan for secrets` with:

```yaml
    - name: Install betterleaks
      env:
        BETTERLEAKS_VERSION: 1.8.1
      run: |
        cd "$(mktemp -d)"
        base="https://github.com/betterleaks/betterleaks/releases/download/v${BETTERLEAKS_VERSION}"
        asset="betterleaks_${BETTERLEAKS_VERSION}_linux_x64.tar.gz"
        curl -sSfL -O "${base}/${asset}" -O "${base}/checksums.txt"
        grep "  ${asset}\$" checksums.txt | sha256sum --check
        tar -xzf "${asset}" betterleaks
        sudo install -m 0755 betterleaks /usr/local/bin/betterleaks
    - name: Scan for secrets
      run: betterleaks git --no-banner --redact --verbose
```

The `checkout` step keeps `fetch-depth: 0`. No test references the Go steps (`grep -rn "go install\|setup-go" test spec` prints nothing).

- [ ] **Step 5: Run the spec and rubocop, then commit**

Run: `bundle exec rspec spec/gempilot/betterleaks_task_spec.rb --no-color && bundle exec rubocop lib/gempilot/betterleaks_task.rb spec/gempilot/betterleaks_task_spec.rb`
Expected: `5 examples, 0 failures`; `2 files inspected, no offenses detected`.

```bash
git add lib/gempilot/betterleaks_task.rb spec/gempilot/betterleaks_task_spec.rb data/templates/gem/dotfiles/github/workflows/secrets.yml .github/workflows/secrets.yml
git commit -m "Scan non-git gems in dir mode and pin the CI betterleaks install"
```

---

### Task 4: Gate, push, PR

**Files:**
- None modified.

- [ ] **Step 1: Full gate**

Run: `bundle exec rake default 2>&1 | tail -12`
Expected: minitest `122 runs, 0 failures`, RSpec `205 examples, 0 failures`, RuboCop `69 files inspected, no offenses detected`. (The branch's `rake betterleaks` is not part of `default`; with the binary absent its spec prints the install hint and passes.)

- [ ] **Step 2: Smoke the retrofit and the scaffold**

From a scratch directory, with `<repo>` your checkout:

```bash
<repo>/exe/gempilot create --author A --email a@b.c --summary s --ruby-version 4.0.6 --test minitest --no-exe --git --branch master --betterleaks hooked_gem
cd hooked_gem && git config core.hooksPath && ls -l .githooks/pre-commit .github/workflows/secrets.yml
```

Expected: `.githooks`, an executable hook, and the workflow file. Then in any older generated gem, `<repo>/exe/gempilot setup betterleaks` twice: the second run reports `skip` for every step.

- [ ] **Step 3: Stop and hand off**

The plan ends here. Do not push. PR #21 ("Add betterleaks secret scanning + make dev gems JRuby-safe", opened 2026-07-26) already tracks this branch; the merge commit and the Task 3 commit are fast-forward additions to it, so a plain `git push origin betterleaks-jruby` by David updates the PR with no history rewrite. An agent executing this plan reports the green gate and leaves the push to him.
