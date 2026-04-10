# Version Management Redesign

Review notes for `new_version_utils.patch`. To be addressed in a follow-up PR.

## Patch summary

Replaces inline rake task logic (including the `ActiveVersion` delegator) with
proper domain objects: `Project`, `Project::Version`, `VersionTag`,
`GithubRelease`, and `StrictShell`. Fixes the stale `require_relative` bug by
using `load` + `refresh_version!` to re-read from disk after mutations.

## What works well

- Clean domain decomposition with single-responsibility classes
- `Version` as a `Data.define` value object with `tag` and `next_version`
- Symmetric `version:release` / `version:unrelease` task pairs
- Array-form `sh` calls throughout (no shell interpolation risk)
- `VersionTag` depends on a version object, not the full project

## Open items

1. **`release_full_spec.rb` is stale** -- matches `task full: ["version:bump",
   "version:commit", :release]` but the new rake file has
   `task release: ["version:bump", "version:commit", "version:tag"]`.

2. **rakelib couples to lib** -- `Project` requires
   `lib/core_ext/string/refinements/inflectable`. Generated gems using this
   rakelib pattern would need that refinement at that exact path.

3. **`Project#klass` loads the gem module** -- `Object.const_get(name.camelize)`
   combined with `load` in `fetch_version` means the gem must be loadable from
   the rake context. Gems with load-time side effects could behave unexpectedly.

4. **`Project` has two responsibilities** -- structure discovery (name, lib path,
   module) and version lifecycle (increment, write, refresh). Cohesive enough for
   now, but the seam is visible if either grows.

5. **`warning` gem dependency** -- `Project` requires the `warning` gem. Needs to
   be a development dependency in the gemspec (and in generated gem templates).

6. **Template expansion** -- If this rakelib replaces `version.rake.erb`, the
   template needs to generate all five support files (`project.rb`,
   `project_version.rb`, `version_tag.rb`, `github_release.rb`,
   `strict_shell.rb`), significantly expanding the scaffold.
