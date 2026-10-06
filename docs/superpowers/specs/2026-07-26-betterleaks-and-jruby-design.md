# Design: JRuby-safe dev gems + betterleaks integration

- **Date:** 2026-07-26
- **Status:** Approved (design), pending spec review
- **Issues:** `986E0100-88F4-11F1-B718-FE6CB9572C2D` (rbs mri-only), `3FFE7616-88F5-11F1-8D3B-FE6CB9572C2D` (add betterleaks)

These are two independent changes bundled into one spec because they were requested together. Issue A is a small, isolated Gemfile fix. Issue B is the substantive feature.

---

## Issue A — Make `rbs` and other native dev gems MRI-only

### Problem
gempilot is sometimes run under JRuby. gempilot's own `Gemfile` declares `rbs` and `repl_type_completor` (which depends on `rbs`), plus `debug` — all of which carry native extensions that fail to build on JRuby, breaking `bundle install`. The reporter observed the irb/`repl_type_completor` stack failing to install because of `rbs`.

### Scope
gempilot's own `/workspace/Gemfile` **only**. The generated-gem template (`data/templates/gem/Gemfile.erb`) is unaffected: it declares plain `irb` (pure Ruby, works on JRuby) and does **not** declare `rbs`, `repl_type_completor`, or `debug`.

### Change
Wrap the native-extension development gems in a platform guard:

```ruby
# rbs, repl_type_completor, and debug ship native extensions that fail to
# build on JRuby; scope them to MRI so `bundle install` succeeds elsewhere.
platforms :mri do
  gem "debug", "~> 1.10"
  gem "rbs"
  gem "repl_type_completor"
end
```

The three gems are removed from their current top-level positions in the Gemfile and moved into this block. All other gems remain unchanged.

### Verification
- `bundle install` on MRI still resolves and installs identically (these gems are still installed on MRI).
- `bundle lock` / install does not attempt to build the native gems on non-MRI platforms.
- Regression test is impractical (bundler platform resolution); rely on the explanatory comment + manual confirmation that MRI is unaffected.

---

## Issue B — Integrate betterleaks secret scanning

### Background
[betterleaks](https://github.com/betterleaks/betterleaks) is a Go binary and a drop-in successor to Gitleaks (same config/flags), by the original Gitleaks author. It is **not** a Ruby gem, so it cannot be added to a Gemfile or installed by bundler. Integration therefore means: a git hook, a rake task, and a CI job — plus graceful behavior when the binary is absent.

Verified facts:
- Install: `brew install betterleaks`, `go install github.com/betterleaks/betterleaks@latest`, `docker pull ghcr.io/betterleaks/betterleaks:latest`, `dnf install betterleaks`.
- Staged/pre-commit scan (from the project's official `.pre-commit-hooks.yaml`): `betterleaks git --pre-commit --redact --staged --verbose`.
- Full scan subcommands: `betterleaks git` (scans history), `betterleaks dir` (scans a directory tree).
- Config file: `betterleaks.toml` (also reads `gitleaks.toml` for back-compat). Defaults work with no config; we ship none.

### Goals
1. New gems created by `gempilot create` get betterleaks wired in by default.
2. Existing gempilot-generated gems can retrofit the same integration with one command.
3. gempilot itself dogfoods the integration.
4. Missing binary never blocks local work; CI enforces.

### Non-goals (YAGNI)
- No `betterleaks.toml` shipped (defaults suffice; users add one if they need allowlists).
- No support for hook managers other than the tracked `.githooks/` script.
- No generic pluggable "integration" framework beyond the single `setup FEATURE` dispatch.

### The integration = four artifacts

| # | Artifact | Behavior |
|---|----------|----------|
| 1 | `.githooks/pre-commit` (executable) | Runs `betterleaks git --pre-commit --redact --staged --verbose`. If `betterleaks` is not on `PATH`, prints an install hint to stderr and exits `0` (does not block the commit). Non-zero betterleaks exit (secret found) aborts the commit. |
| 2 | `core.hooksPath = .githooks` | Points git at the tracked hooks dir. Set by `bin/setup` (so fresh clones activate on setup) and set immediately by the retrofit command. Stored in `.git/config` (not committed), hence the `bin/setup` step. |
| 3 | `rake betterleaks` | Full-repo scan (`betterleaks git --redact --verbose`). Shipped by the gempilot gem as `Gempilot::BetterleaksTask < Rake::TaskLib` (same pattern as `VersionTask`/`ZeitwerkTask`). Skips with an install hint (does not fail the task) if the binary is absent. |
| 4 | `.github/workflows/secrets.yml` | CI job on push/PR: checkout (full history), `actions/setup-go`, `go install github.com/betterleaks/betterleaks@latest`, then `betterleaks git --redact`. This job **enforces** — a finding fails CI. Kept as a **separate** workflow from `ci.yml` so retrofit is a clean file drop with no YAML surgery. |

The hook script (1) is a static file (no gem-specific interpolation). The workflow (4) is static. Artifacts (2) and (3)'s wiring lines are the only edits to existing files.

### Wiring points

**1. `gempilot create` — new gems**
- Add option: `option :betterleaks, long: "--[no-]betterleaks", desc: "Set up betterleaks secret scanning"`.
- Collect it like `--exe`/`--git`: honor the flag if given; otherwise prompt interactively with **default yes**. Store as `@betterleaks`.
- In `GemBuilder`, when `@betterleaks`:
  - copy `.githooks/pre-commit` (+ `chmod +x`),
  - copy `.github/workflows/secrets.yml`,
  - `Rakefile.erb` and `bin/setup.erb` include their wiring lines via `<% if @betterleaks -%>` conditionals,
  - set `core.hooksPath` in the new repo during `initialize_git_repo` (when git is enabled).

**2. `gempilot setup betterleaks` — existing gems (new command)**
- New autoloaded command `lib/gempilot/cli/commands/setup.rb` → `Gempilot::CLI::Commands::Setup`.
- Usage `setup [options] FEATURE`; `argument :feature`; dispatch mirrors `new`/`destroy`:
  ```ruby
  def run(feature = nil)
    feature ||= prompt_for_feature   # ask_multiple_choice %w[betterleaks]
    detect_gem_context               # from GemContext
    dispatch_setup(feature)          # case feature when "betterleaks" ... else error+exit 1
  end
  ```
- `setup_betterleaks` is **idempotent** and prints `create`/`skip` actions (reusing `Generator`/`destroy`-style output):
  - create `.githooks/pre-commit` (+chmod) if absent, else skip,
  - create `.github/workflows/secrets.yml` if absent, else skip,
  - append the `require "gempilot/betterleaks_task"` + `Gempilot::BetterleaksTask.new` lines to `Rakefile` only if not already present,
  - append `git config core.hooksPath .githooks` to `bin/setup` only if not already present (create a minimal `bin/setup` if the gem lacks one),
  - run `git config core.hooksPath .githooks` immediately so the hook is live.

**3. gempilot's own repo — dogfood**
- Add `.githooks/pre-commit` and `.github/workflows/secrets.yml`.
- Add `require "gempilot/betterleaks_task"` + `Gempilot::BetterleaksTask.new` to `/workspace/Rakefile`.
- Add `git config core.hooksPath .githooks` to `/workspace/bin/setup`; set the config in the working repo.

### Shared boundary
A small mixin `Gempilot::CLI::BetterleaksInstaller` (`lib/gempilot/cli/betterleaks_installer.rb`) is the single source of truth for the integration: the canonical relative paths, the hook/workflow template sources, and the Rakefile/`bin/setup` snippet strings, plus file-copy helpers parameterized by a destination root (`@gem_name/` for `create`, `.` for `setup`). `create` (via `GemBuilder`) and the `Setup` command are its two consumers — `create` renders fresh (ERB conditionals), `setup` patches idempotently. This keeps "what the integration is" defined once.

### Error handling
- **Binary absent:** hook and rake task print an install hint and succeed (exit 0 / task no-op). CI installs the binary and enforces.
- **Not in a gem repo** (`setup`): `GemContext#detect_gem_context` already prints a clear message and exits 1.
- **Unknown feature** (`setup foo`): print `Unknown feature 'foo'. Available: betterleaks.` and exit 1 (mirrors `new`/`destroy`).
- **Re-run `setup betterleaks`:** every step is create-if-absent / append-if-absent; a second run reports all `skip`.
- **Secret found:** betterleaks exits non-zero → hook aborts the commit; task/CI fail.

### Files touched

**gempilot repo — new files**
- `lib/gempilot/betterleaks_task.rb` — `Gempilot::BetterleaksTask < Rake::TaskLib`.
- `lib/gempilot/cli/betterleaks_installer.rb` — `BetterleaksInstaller` mixin.
- `lib/gempilot/cli/commands/setup.rb` — `Setup` command.
- `data/templates/gem/githooks/pre-commit` — hook script (static).
- `data/templates/gem/dotfiles/github/workflows/secrets.yml` — CI workflow (static).
- `.githooks/pre-commit` — gempilot's own hook (dogfood).
- `.github/workflows/secrets.yml` — gempilot's own workflow (dogfood).

**gempilot repo — modified files**
- `/workspace/Gemfile` — Issue A `platforms :mri` block.
- `lib/gempilot/cli/commands/create.rb` — `--[no-]betterleaks` option + collection.
- `lib/gempilot/cli/gem_builder.rb` — render betterleaks artifacts when `@betterleaks`; set hooksPath on git init.
- `data/templates/gem/Rakefile.erb` — conditional betterleaks task wiring.
- `data/templates/gem/bin/setup.erb` — conditional `core.hooksPath` line.
- `/workspace/Rakefile` — dogfood `Gempilot::BetterleaksTask.new`.
- `/workspace/bin/setup` — dogfood `core.hooksPath` line.

### Testing (minitest, following existing `test/` patterns)
- **create:** `--betterleaks` renders `.githooks/pre-commit` (executable), `secrets.yml`, and the Rakefile/bin-setup wiring lines; `--no-betterleaks` omits all of them.
- **setup command:** retrofit into a fixture gem creates the artifacts and patches Rakefile/bin-setup; a second run reports `skip` for every step (idempotency); running outside a gem exits 1; unknown feature exits 1.
- **BetterleaksTask:** defines a `betterleaks` rake task; with `betterleaks` stubbed off `PATH`, the task no-ops with a hint rather than failing.
- **installer mixin:** unit-level check that the canonical paths/snippets are applied under a given destination root.
- gempilot's own suite (`rake zeitwerk:validate`, `rubocop`, `test`, `spec`) stays green after the dogfood changes.

### Risks / details to confirm at implementation
- Exact CI install path: `go install github.com/betterleaks/betterleaks@latest` is confirmed from the project README and is the chosen method; if an official GitHub Action proves more robust it may be substituted, but the Go install is the default.
- Exact full-scan flags (`betterleaks git --redact --verbose`) to be confirmed against `betterleaks git --help` during implementation; the pre-commit invocation is taken verbatim from the official hook definition.

### Out of scope
- Migrating existing generated gems' `ci.yml`; the separate `secrets.yml` sidesteps this.
- Any secret-scanning config/allowlist customization.
