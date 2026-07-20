# Release task hierarchy — design

**Issue:** `2C8EF3C8-83E9-11F1-9256-FE6CB9572C2F` — "gh release tasks need adjusting in task hierarchy"

**Date:** 2026-07-20

## Problem

Gempilot installs GitHub release tasks under a bespoke `version:github:*` namespace
(`version:github:release/unrelease/list`). Two things are wrong:

1. **Wrong hierarchy.** GitHub publishing should live in the standard `release` /
   `unrelease` namespace alongside RubyGems publishing, not in a custom
   `version:github:*` corner.
2. **GitHub releasing is broken.** The release flow bumps + commits + tags *locally*
   via `version:release` (`version:tag` runs `git tag vX`). When the actual publish
   runs through bundler's `release` task, bundler's `already_tagged?` guard sees the
   tag already exists locally, prints *"Tag vX has already been created."*, and
   **skips `release:source_control_push` entirely** — so the commit and tag never
   reach the remote, and `gh release create vX` has nothing to attach to. This is the
   "tags have already been pushed / doesn't work at all" symptom in the issue.

This is an approved **breaking change**. No backwards compatibility for the old
`version:github:*` tasks.

## Decisions

- **Namespace-only interface. No `[remote]` argument.** Target selection lives in the
  task name (`release:github`), not an argument. This is the idiomatic Rake convention
  (task name = what to do; argument = a value), and it avoids a direct collision:
  `bundler/gem_tasks` already defines `task "release", [:remote]` where `remote` means
  the *git remote name* (`origin`) passed to `git push`. Overloading that same word to
  mean "publish target" is exactly what made the original `release[remote]` idea
  confusing. So the final interface uses no argument at all.
- **Bare `rake release` publishes to all remotes** (RubyGems + GitHub), expressed as a
  pure prerequisite composite — no dispatcher code.
- **Reuse bundler's building blocks for RubyGems.** `release:rubygems` composes
  bundler's existing `build`, `release:guard_clean`, and `release:rubygem_push` leaf
  tasks via prerequisites. No new object wraps them — this preserves `allowed_push_host`
  (private gem servers), MFA/OTP prompts, and `gem_push=no`.
- **Fix the bug by overriding the one task that is wrong.** Replace bundler's
  `release:source_control_push` with an idempotent push (no `already_tagged?` guard),
  done the same idiomatic way bundler does it: an explicit `git push <remote> <branch>`
  then `git push <remote> <tag>`. Both remotes share this single task as a prerequisite,
  so both get the fix and the push runs exactly once per release.
- **Keep the local version lifecycle as-is.** `version:release` / `version:unrelease`
  (local bump → commit → tag) are unchanged. The `version:` namespace and the top-level
  `release` do not collide in Rake.

## Task interface

| Task | Behavior |
| --- | --- |
| `rake release` | Publish current version to all remotes (RubyGems + GitHub) |
| `rake release:rubygems` | Build + push the gem to RubyGems |
| `rake release:github` | Push commit + tag, then create the GitHub release |
| `rake release:list:github` | List GitHub releases |
| `rake unrelease` | Delete the release from all remotes that support it (GitHub) |
| `rake unrelease:github` | Delete the GitHub release and remote tag |

`rake unrelease:rubygems` is intentionally undefined — Rake fails with "Don't know how
to build task", which is the correct signal that RubyGems yanking is out of scope.

## Task definitions

Defined in `Gempilot::VersionTask`, replacing the current `define_github_tasks`. Runs
after `require "bundler/gem_tasks"` (guaranteed by the generated `Rakefile` and by
gempilot's own `Rakefile`), so bundler's tasks exist when we override them. Each
override is guarded with `task_defined?` so the definitions also work when bundler's
gem tasks are absent (e.g. gempilot's own spec suite).

```ruby
# THE FIX: idempotent push, replacing bundler's already_tagged?-guarded task.
Rake::Task["release:source_control_push"].clear if Rake::Task.task_defined?("release:source_control_push")
task "release:source_control_push" do
  Origin.new(project.version_tag).push
end

namespace :release do
  desc "Release the current version to RubyGems"
  task rubygems: %w[build release:guard_clean release:source_control_push release:rubygem_push]

  desc "Create a GitHub release for the current version"
  task github: "release:source_control_push" do
    GithubRelease.new(project.version_tag).create
  end

  namespace :list do
    desc "List GitHub releases"
    task(:github) { GithubRelease.new(project.version_tag).list }
  end
end

Rake::Task["release"].clear if Rake::Task.task_defined?("release")
desc "Release the current version to all remotes"
task release: %w[release:rubygems release:github]

desc "Delete the current release from all remotes that support it"
task unrelease: %w[unrelease:github]

namespace :unrelease do
  desc "Delete the GitHub release for the current version"
  task(:github) { GithubRelease.new(project.version_tag).destroy }
end
```

## Components

### `Gempilot::Origin` (new — `lib/gempilot/origin.rb`)

A small domain object (same style as the existing `GithubRelease` / `VersionTag`) that
pushes the current branch and a given tag to the branch's configured git remote. This
backs `release:source_control_push` and is the bug fix.

- `initialize(tag)` — the version tag string (e.g. `"v1.0.0"`).
- `#push` — runs, via `StrictShell#sh`:
  - `git push <remote> refs/heads/<branch>`
  - `git push <remote> refs/tags/<tag>`
- `<branch>` = `git rev-parse --abbrev-ref HEAD`; `<remote>` = the branch's configured
  remote (`git config --get branch.<branch>.remote`), defaulting to `origin` — mirroring
  bundler's own `current_branch` / `default_remote` logic.
- Idempotent: pushing an already-pushed branch/tag exits 0 ("Everything up-to-date"),
  so re-running a release never fails on the tag. This is the property bundler's guard
  broke.

### `Gempilot::GithubRelease` (modified — `lib/gempilot/github_release.rb`)

- `#create` drops its two internal `git push` / `git push --tags` lines. Pushing is now
  `Origin`'s job (the `release:source_control_push` prerequisite runs first). `create`
  becomes purely: `gh release create --generate-notes --fail-on-no-commits <tag>`.
- `#destroy` and `#list` are unchanged.

### `Gempilot::VersionTask` (modified — `lib/gempilot/version_task.rb`)

- Remove `define_github_tasks` and its call in `define_tasks`.
- Add the release / unrelease definitions above (a `define_release_tasks` +
  `define_unrelease_tasks`, or equivalent private methods keeping RuboCop metrics
  satisfied — small focused methods).
- `version:*` local lifecycle tasks and `version:release` / `version:unrelease`
  composites are untouched.

There is **no** `RubygemsRelease` object. RubyGems publishing is bundler-task
composition only.

## Data flow

- `rake release:github` → `release:source_control_push` (push commit + tag) →
  `gh release create`.
- `rake release:rubygems` → `build` → `release:guard_clean` →
  `release:source_control_push` (push commit + tag) → `release:rubygem_push` (gem push).
- `rake release` → `release:rubygems` (which pushes during its chain), then
  `release:github`. Rake invokes `release:source_control_push` once, so the git push
  happens a single time, before both publishes.
- `rake unrelease` → `unrelease:github` → `gh release delete --yes --cleanup-tag`
  (removes the GitHub release and the remote tag).

## Error handling

- **Unsupported unrelease target** (`rake unrelease:rubygems`): undefined task → Rake's
  native "Don't know how to build task" error. No custom code.
- **Shell failures**: every git / gh / gem command runs through `StrictShell#sh`, which
  already raises on non-zero exit.
- **Tag / commit not pushable**: if the local tag does not exist, the `git push
  refs/tags/<tag>` fails loudly via `StrictShell` — the correct signal to run
  `version:release` first. No separate guard task is added (deliberate: the
  `version:release` flow is responsible for producing a clean, tagged commit; adding a
  bundler-independent `guard_clean` is out of scope).

## Testing (TDD)

Written before implementation.

**`spec/gempilot/origin_spec.rb` (new)**
- `#push` issues `git push <remote> <branch>` then `git push <remote> <tag>` in order
  (stub `sh`, assert ordered calls; assert branch/remote resolution).
- **Regression / integration**: in a tmpdir, create a real repo with a bare "origin"
  remote and a tag, run `Origin#push`, assert the commit + tag land on origin; run it a
  **second** time and assert it still succeeds (idempotent) — directly proving the bug
  (bundler's guarded skip) is fixed.

**`spec/gempilot/github_release_spec.rb` (modified)**
- `#create` no longer calls `git push` / `git push --tags`; it calls only
  `gh release create --generate-notes --fail-on-no-commits <tag>`.
- `#destroy` and `#list` specs unchanged.

**`spec/gempilot/version_task_spec.rb` (extended)**
- **Structure**: `release`, `release:rubygems`, `release:github`, `release:list:github`,
  `unrelease`, `unrelease:github` are defined; `version:github:release`,
  `version:github:unrelease`, `version:github:list` are **not**.
- **Composites by prerequisite** (no invocation needed): `release` prerequisites ==
  `%w[release:rubygems release:github]`; `release:rubygems` prerequisites ==
  `%w[build release:guard_clean release:source_control_push release:rubygem_push]`;
  `unrelease` prerequisites == `%w[unrelease:github]`.
- **Behavior by invocation** (stub `Origin` / `GithubRelease` constructors):
  - `release:source_control_push` invokes `Origin#push`.
  - `release:github` runs the push, then `GithubRelease#create`.
  - `release:list:github` invokes `GithubRelease#list`.
  - `unrelease:github` invokes `GithubRelease#destroy`.
  - `release:rubygems` is asserted by prerequisites only (its bundler prerequisites are
    absent in the spec's fresh Rake app, so it is not invoked there).

## Docs

- `README.md` — replace the three `version:github:*` rows in the tasks table with the
  new `release` / `unrelease` tasks; update the `gempilot release` note to reflect that
  bare `rake release` now publishes to all remotes.
- `CLAUDE.md` — update the "Version lifecycle rake tasks" bullet: drop
  `version:github:release/unrelease/list`, add `release` / `release:rubygems` /
  `release:github` / `release:list:github` / `unrelease` / `unrelease:github`.

## Out of scope

- `data/templates/gem/Rakefile.erb` needs no change — it already requires
  `bundler/gem_tasks` before `Gempilot::VersionTask.new`, which the override relies on.
- The stale `rakelib/*` excludes in `data/templates/gem/dotfiles/rubocop.yml.erb`
  (including `rakelib/github_release.rb`) belong to a separate open issue about internal
  concerns leaking to gem users (`B45C988A`). Not touched here.
- RubyGems yanking (`unrelease:rubygems`).
- The `gempilot release` CLI command keeps proxying to `rake release`; its behavior
  changes only because bare `rake release` now targets all remotes.
- Any change to the local `version:*` lifecycle tasks.
