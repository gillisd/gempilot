# Design: Own the shared RuboCop config in gempilot, with an eject hatch

Issue: `79AE436E` — "Own shared config in gempilot and consume it, with an eject hatch"
Date: 2026-07-20
Status: **Draft — awaiting review.** Design direction approved in brainstorming
(mechanism = `inherit_gem`, local config = near-zero). One decision deferred by
the user (see [Open decision](#open-decision-ci-break-mitigation)); documented
with a recommended default so implementation is unblocked.

## Problem

Almost everything gempilot gives a generated gem is copied in as a template
file. The clearest case is `.rubocop.yml`, rendered from the ~200-line
`data/templates/gem/dotfiles/rubocop.yml.erb` into each gem with no link back to
gempilot. Once written it belongs to the user's repo and drifts, so improving a
shared rule means hand-recopying into every gem.

gempilot already avoids this for rake tasks: the generated `Rakefile` does
`require "gempilot/version_task"; Gempilot::VersionTask.new` (and, as of this
session, `Gempilot::ZeitwerkTask.new`), and gems already depend on gempilot
(`gem "gempilot", require: false`). That logic lives in gempilot and rolls
forward on a version bump. This design extends the same "own, don't copy" model
to the copied RuboCop config.

## Goals / non-goals

**In scope**
- Ship gempilot's curated RuboCop config *inside* the gem and have generated
  gems consume it by reference, so config improvements roll forward.
- Shrink the generated `.rubocop.yml` to near-zero (just the reference + the
  irreducible per-gem bits).
- An **eject** command that inlines the referenced config and cuts the link, so
  a gem can opt out and drift freely.

**Out of scope (deferred)**
- **CLAUDE.md.** There is no CLAUDE.md generation today, and markdown has no
  `inherit_gem`/plugin analog. It would need a regen command or a stub pointing
  at gempilot-shipped content, not parity. Handle separately, later.
- Sharing any other config (CI workflow, gitignore, etc.). RuboCop first; the
  eject command is built so it *can* generalize, but only RuboCop is wired now.

## Decisions

| Decision | Choice | Why |
|---|---|---|
| Mechanism | **`inherit_gem`** (not a plugin) | gempilot ships **no cops of its own** — only a curated config (which external plugins to load + cop-setting overrides). A RuboCop plugin conventionally bundles cops; `inherit_gem` is the honest fit for shipping config. |
| Local config size | **Near-zero** | Move gem-name excludes to globs (`*.gemspec`, `lib/*-*.rb`) and drop `TargetRubyVersion` (RuboCop reads `required_ruby_version` from the gemspec, which the template already sets). Leaves just the `inherit_gem` reference. |
| Config update policy | **Pin + deliberate update** (recommended default — see [Open decision](#open-decision-ci-break-mitigation)) | Pin `gem "gempilot", "~> X.Y"` so config changes arrive on an explicit `bundle update gempilot`, not silently on every install. Leverages bundler, no new machinery. |
| Eject scope | **RuboCop only now** | YAGNI. The command is named/shaped to allow future config types but only ejects `.rubocop.yml` today. |

## Architecture

Three moving parts, mirroring the existing `VersionTask`/`ZeitwerkTask` "gempilot
owns it, the gem references it" pattern.

### 1. gempilot ships the config

Extract the **static bulk** of `rubocop.yml.erb` into real YAML files shipped in
the gem and packaged via the gemspec (`git ls-files` picks them up once
committed):

```
config/rubocop/base.yml       # gem- and framework-agnostic (the ~140 stable lines)
config/rubocop/minitest.yml   # minitest-only slice
config/rubocop/rspec.yml      # rspec-only slice
```

`Gempilot::ROOT` already exists (`lib/gempilot.rb`) and is used to locate
`data/templates`; the eject command uses it to locate `config/rubocop`.

### 2. Generated gem references it

The generated `.rubocop.yml` template collapses from ~200 lines to:

```yaml
inherit_gem:
  gempilot:
    - config/rubocop/base.yml
    - config/rubocop/rspec.yml   # or minitest.yml — chosen at create time
```

Nothing else is needed because:
- **TargetRubyVersion** → RuboCop reads it from the gemspec's
  `required_ruby_version` (template already sets `>= <ruby_version>`).
- **Gemspec excludes** (`Metrics/BlockLength`, `Claude/NoFancyUnicode`) → use the
  `*.gemspec` glob in `base.yml` instead of `<gem_name>.gemspec`.
- **Hyphenated shim exclude** (`lib/<gem-name>.rb`) → use the `lib/*-*.rb` glob in
  `base.yml`. Only hyphenated gems have such a file; harmless for others.
- **Framework choice** → the one genuinely per-gem line: which framework file is
  inherited. Chosen at `gempilot create` time from `@test_framework`.

The generated **Gemfile** pins the dependency:
`gem "gempilot", "~> <major.minor>", require: false` (was unpinned).

### 3. `gempilot eject`

New command (`lib/gempilot/cli/commands/eject.rb`, auto-loaded by
`CommandKit::Commands::AutoLoad`, runs from the gem root via `GemContext`).
Behavior:

1. Read the gem's current `.rubocop.yml`, find the `inherit_gem: { gempilot: [...] }`
   file list (fall back to detecting the framework via `GemContext` if absent).
2. Read those files from the installed gempilot (`Gempilot::ROOT/config/rubocop/*.yml`).
3. Concatenate them (base + framework) with a generated header noting it was
   ejected from gempilot vX.Y, plus any local keys that were already in
   `.rubocop.yml` alongside the `inherit_gem` stanza.
4. Write the merged result back to `.rubocop.yml` and **remove** the `inherit_gem`
   stanza.

The result is a self-contained config equivalent to today's copied file — i.e.
eject reproduces the pre-change behavior on demand. This is deterministic
(concatenate shipped files) rather than relying on RuboCop's internal config
resolver, so the output is clean and predictable.

## The static/dynamic split (from `rubocop.yml.erb`)

RuboCop merges same-cop config as a **hash** by default (keys combine), so the
split is clean as long as no single array key (e.g. `AllowedMethods`) is set in
two inherited files. Assignment:

- **`base.yml`** (no `plugins:` line, no `AllowedMethods`): `AllCops` (`NewCops`,
  `Exclude: [bin/*, vendor/**/*, lib/*-*.rb]`); all `Style/*`, `Layout/*`,
  `Claude/*`, `Performance/*` overrides (template lines ~36–93, 127–173);
  `Metrics/BlockLength: {Max: 8, CountAsOne: [...], Exclude: ["*.gemspec"]}`;
  `Claude/NoFancyUnicode: {Exclude: ["*.gemspec"]}`; `Style/Documentation:
  {Enabled: true}`.
- **`minitest.yml`**: `plugins: [rubocop-claude, rubocop-performance,
  rubocop-rake, rubocop-minitest]`; `Metrics/BlockLength: {AllowedMethods:
  [command, test]}`; `Minitest/MultipleAssertions: {Max: 10}`;
  `Style/Documentation: {Exclude: ["test/**/*"]}`.
- **`rspec.yml`**: `plugins: [..., rubocop-rspec]`; `Metrics/BlockLength:
  {AllowedMethods: [command, describe, context, shared_examples,
  shared_examples_for, shared_context]}`; `RSpec/MultipleMemoizedHelpers:
  {Max: 10}`; `Style/Documentation: {Exclude: ["spec/**/*"]}`; the `RSpec/*`
  overrides (DescribeClass, LeadingSubject, ExpectChange, NamedSubject,
  ExpectActual).

`plugins:` lives **only** in the framework files (each lists the full set) so
there is no plugin-array merge to reason about. `base.yml` may reference
`Claude/*` and `Performance/*` cops even though it does not declare the plugins,
because RuboCop loads all plugins from the fully-merged inheritance chain before
applying cop settings.

## Risks / spikes (validate early)

1. **Plugins through `inherit_gem`** — *load-bearing.* Confirm RuboCop actually
   loads `plugins:` declared in an inherited-gem config (not just cop settings).
   If it does not, the `plugins:` list must stay in the thin local `.rubocop.yml`
   (a small change: local file gains ~6 lines, still far below 200). **Spike this
   first** with a throwaway generated gem before building the rest.
2. **Array-merge surprises** — verify `AllowedMethods` (set only in framework
   files) and other arrays merge/replace as expected across base + framework.
3. **Eject fidelity** — the ejected `.rubocop.yml` must lint the gem identically
   to the inherited version. Assert by running RuboCop on a generated gem before
   and after eject and diffing offenses (should be none).
4. **`required_ruby_version` → TargetRubyVersion** — confirm RuboCop picks up the
   target from the gemspec when `.rubocop.yml` omits `TargetRubyVersion`.

## Testing strategy (TDD)

Unit / component (RSpec, under `spec/`):
- **Shared config validity**: each shipped `config/rubocop/*.yml` loads as valid
  RuboCop config.
- **Generated `.rubocop.yml`** (create spec, `sh`-stubbed for speed): contains
  the `inherit_gem` block with base + the correct framework file; contains no
  copied override bodies; picks `rspec.yml` vs `minitest.yml` by framework.
- **Generated Gemfile**: pins `gem "gempilot", "~> X.Y"`.
- **`gempilot eject`**: in a tmp gem with an `inherit_gem` `.rubocop.yml`, after
  eject the file contains the inlined overrides and no `inherit_gem`; is
  idempotent-safe / errors cleanly if already ejected.

Integration (extends existing `test_generated_gem_default_rake_task_passes`
pattern — patches Gemfile to local gempilot path, runs the generated gem's
rake): the generated gem's default rake (which runs RuboCop) **passes using the
inherited config**, for both frameworks and for a hyphenated gem. This is the
real proof that `inherit_gem` + plugins works end to end.

## Implementation sequence

1. **Spike** risk #1 (plugins via `inherit_gem`) in a throwaway generated gem.
   Adjust the split if plugins must stay local.
2. Add `config/rubocop/{base,minitest,rspec}.yml` (mechanical extraction from the
   ERB template). Add a spec asserting each loads.
3. Rewrite `dotfiles/rubocop.yml.erb` to the near-zero `inherit_gem` form; update
   the existing create/rubocop specs and `create_command_test.rb` assertions.
4. Pin gempilot in `Gemfile.erb`; update its spec.
5. Confirm the integration test passes (both frameworks + hyphenated).
6. Build `gempilot eject` (command + `GemContext` wiring + specs).
7. Docs: README + CLAUDE.md note the shared config and `gempilot eject`.

## Open decision: CI-break mitigation

Auto-propagating config on a bump can add cop offenses and break CI with no code
change (generated gems set `NewCops: enable` and run RuboCop in the default
task). The user deferred this choice. **Recommended default: pin** (`gem
"gempilot", "~> X.Y"`) so updates are opt-in via `bundle update gempilot`.
Alternatives to revisit: always live-linked (simplest, riskiest); or a changelog
/ opt-in gate (most control, most machinery). Implementation assumes **pin**
unless changed on review.

## Backward compatibility

Existing generated gems are unaffected — they keep their copied `.rubocop.yml`.
This changes only what **new** `gempilot create` runs emit. No migration is
provided for existing gems (they can hand-adopt the `inherit_gem` stanza if they
want to opt in); `eject` is the reverse path for new gems that want to opt out.
