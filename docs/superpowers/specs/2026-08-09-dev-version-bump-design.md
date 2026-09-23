# Dev version bump semantics — design

**Issue:** `2360FFA4-9388-11F1-8474-FE6CB9572C2F` — "rake version:bump[dev] goes backward rather than forward"

**Date:** 2026-08-09

## Problem

`Gempilot::Project::Version#bump(:dev)` appends `.dev1` to the *current* version
(`0.2.0` → `0.2.0.dev1`). RubyGems treats any version with a letter segment as a
**prerelease of the version it names** (`Gem::Version` rdoc: "Prereleases sort
between real releases (newest to oldest): 1.0 > 1.0.b1 > 1.0.a.2 > 0.9"), so
`0.2.0.dev1 < 0.2.0` — the bump moves the project *backward*. Two related gaps:

1. `bump(:patch)` from `X.Y.Z.devN` produces `X.Y.(Z+1)`, overshooting the
   `X.Y.Z` the dev cycle was working toward.
2. There is no way to bump a fourth integer (`0.2.0` → `0.2.0.1`), the
   rubygems-legal *non-prerelease* shape for tiny follow-up fixes on a released
   version (the Rails security-release pattern, `6.0.3.1`).

## Decisions

- **Dev versions preview the next patch.** `bump(:dev)` from a release version
  yields the next patch's first dev prerelease (`0.2.0` → `0.2.1.dev1`); from a
  dev version it increments the counter (`0.2.1.dev1` → `0.2.1.dev2`). This is
  the only reading consistent with rubygems ordering, and matches ecosystem
  practice (Rails `7.1.0.beta1` precedes `7.1.0`; Bundler's in-repo `.dev`).
- **One rule governs every bump: move to the smallest version of the requested
  shape that is strictly greater than the current version.** Consequences:
  numeric bumps from a dev version *finalize* the cycle (`0.2.1.dev3` +
  `patch` → `0.2.1`, not `0.2.2`), and `minor`/`major` redirect it
  (`0.2.1.dev3` + `minor` → `0.3.0`).
- **New `tiny` segment for the fourth integer.** `bump(:tiny)`: `0.2.0` →
  `0.2.0.1` → `0.2.0.2`. Name chosen by elimination: semver's "build metadata"
  is precedence-ignored (and the `Gem::Version` rdoc uses "build" for the third
  integer); `micro` is Python's third digit; `patchlevel` is Ruby-historical but
  long and confusable with `patch`. `tiny` reads as "smaller than patch", which
  is where it sorts. (Old Rails used TINY for the third digit; accepted.)
- **No dev target argument** (`bump[dev,minor]` → `0.3.0.dev1`) — YAGNI. The
  shape rule already finalizes hand-edited `M.m.0.devN` / `M.0.0.devN` states
  correctly, so a targeted form can be layered on later without breaking
  anything.
- **Dev GitHub releases are prereleases.** `release:github` passes
  `--prerelease` to `gh release create` when the tag names a prerelease
  version, so `v0.2.1.dev2` does not become the repo's "Latest" release.
- **Strict version parsing.** `Version#bump` recognizes exactly three forms —
  `M.m.p`, `M.m.p.N`, `M.m.p.devN` — and raises `ArgumentError` for anything
  else, instead of today's silent first-three-integers coercion.

## Semantics

Accepted version forms: release `M.m.p`, tiny release `M.m.p.N`, dev prerelease
`M.m.p.devN` (parse: `/\A(\d+)\.(\d+)\.(\d+)(?:\.(\d+)|\.dev(\d+))?\z/`).

Full transition table (rows marked * arise only by hand-editing; the rule is
total over all three forms regardless of how the version got there):

| from ↓ bump → | `major` | `minor` | `patch` | `tiny`    | `dev`        |
| ------------- | ------- | ------- | ------- | --------- | ------------ |
| `1.2.3`       | `2.0.0` | `1.3.0` | `1.2.4` | `1.2.3.1` | `1.2.4.dev1` |
| `1.2.3.1`     | `2.0.0` | `1.3.0` | `1.2.4` | `1.2.3.2` | `1.2.4.dev1` |
| `1.2.4.dev2`  | `2.0.0` | `1.3.0` | `1.2.4` | `1.2.4.1` | `1.2.4.dev3` |
| `1.3.0.dev2`* | `2.0.0` | `1.3.0` | `1.3.0` | `1.3.0.1` | `1.3.0.dev3` |
| `2.0.0.dev2`* | `2.0.0` | `2.0.0` | `2.0.0` | `2.0.0.1` | `2.0.0.dev3` |

All 25 transitions verified strictly increasing under `Gem::Version` (checked
2026-08-09 against ruby's installed rubygems).

Branch logic per segment, where the numeric core is `M.m.p` and `dev?` means
the current version is a dev prerelease:

- `major`: `dev? && m == 0 && p == 0` → `M.0.0` (finalize); else `(M+1).0.0`
- `minor`: `dev? && p == 0` → `M.m.0` (finalize); else `M.(m+1).0`
- `patch`: `dev?` → `M.m.p` (finalize); else `M.m.(p+1)`
- `tiny`:  `M.m.p.(N+1)` where `N` is the current fourth integer, else 0.
  (From a dev version this yields `M.m.p.1` — it implicitly finalizes the
  target and adds a tiny level; forward-moving, documented edge case.)
- `dev`:   `dev?` → `M.m.p.dev(N+1)`; else `M.m.(p+1).dev1`

## Components

### `Gempilot::Project::Version` (modified — `lib/gempilot/project/version.rb`)

- Stays `Data.define(:path, :value)` — `write_version!`, `VersionTag`, and all
  call sites are untouched. Parsing is internal to `bump`.
- `bump(segment)` accepts `:major, :minor, :patch, :tiny, :dev` (symbol or
  string), implements the table above. Unknown segment → `ArgumentError`
  naming the valid segments (as today, plus `tiny`). Unparseable value →
  `ArgumentError` naming the value.
- `next_version` alias retained; its behavior follows the new `patch` default
  (`0.0.4.dev3` → `0.0.4`, previously `0.0.5`).

### `Gempilot::GithubRelease` (modified — `lib/gempilot/github_release.rb`)

- `#create` appends `--prerelease` when the tag (sans leading `v`) parses as a
  prerelease per `Gem::Version#prerelease?`. Self-contained — the
  `initialize(tag)` signature and all call sites are unchanged. `#destroy` /
  `#list` untouched.

### `Gempilot::VersionTask` (modified — `lib/gempilot/version_task.rb`)

- Behavior unchanged (it forwards the segment). Only the `version:bump` desc
  string updates: "Bump version (patch default; segments: major, minor, patch,
  tiny, dev)".

### `Gempilot::CLI::Commands::Bump` (modified — `lib/gempilot/cli/commands/bump.rb`)

- Allowed segments become `%w[patch minor major tiny dev]`; error message,
  argument desc, command description, and `examples` updated to match.

## Testing (TDD — written before implementation)

**`spec/gempilot/project/version_spec.rb` (rewritten)**

- The full 5×5 transition table above, each cell an example.
- A monotonicity property spec: for every table cell,
  `Gem::Version.new(new) > Gem::Version.new(old)` — the direct regression spec
  for this issue.
- Segment as string; unknown segment `ArgumentError`; unparseable value
  (`"1.2"`, `"1.2.3.beta1"`) `ArgumentError`; `next_version` follows patch
  semantics (`0.0.4.dev3` → `0.0.4`).

**`spec/gempilot/version_task_spec.rb` (expectations updated)**

Fixture starts at `1.0.0.dev3`:
- `version:bump` (default patch) → `1.0.0` (finalize; was `1.0.1`).
- `version:bump[dev]` → `1.0.0.dev4` (unchanged).
- `version:bump[tiny]` → `1.0.0.1` (new example).
- `version:release[dev]` → commit "Bump version to 1.0.0.dev4", tag
  `v1.0.0.dev4` (unchanged).

**`spec/gempilot/github_release_spec.rb` (extended)**

- `create` with `v1.2.4.dev1` includes `--prerelease`; with `v1.2.4` and
  `v1.2.3.1` it does not.

**`test/gempilot/cli/bump_command_test.rb` (extended)**

- `tiny` accepted as a segment; unknown-segment error message lists it.

## Docs

- `README.md` — `gempilot bump` section gains `tiny` and `dev` examples with a
  one-line explanation of dev semantics; the rake tasks table row for
  `version:bump` mentions the segments.
- `CLAUDE.md` — version lifecycle bullet: "(patch default, or
  minor/major/tiny/dev)".

## Migration

A repo sitting on an old-style dev version (e.g. `0.2.0.dev1` created *after*
`0.2.0` shipped) is already in the broken state this fixes; `bump(:patch)`
would finalize to the already-released `0.2.0` (and `version:tag` would then
fail on the existing tag). Recovery is a one-time hand edit of `version.rb`
past the last published version. Noted in the README dev-example line.

## Out of scope

- Targeted dev cycles (`bump[dev,minor]`) — compatible later extension.
- Other prerelease markers (`pre`, `rc`, `beta`) — `dev` sorts before all of
  them, so they remain addable later.
- RubyGems prerelease yanking; `data/templates/gem/Rakefile.erb` (no change
  needed — it just instantiates `Gempilot::VersionTask`).
