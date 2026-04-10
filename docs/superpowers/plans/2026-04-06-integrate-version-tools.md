# Package Version Tools as Gem Dependency

## Context

Generated gems currently get 8 files copied into them (rakelib support classes + core_ext inflection files). This creates maintenance burden — files diverge, every gem carries duplicate code, updates require regenerating. The CLI `bump` command also reimplements version logic that `Project` already provides.

Instead: the domain model (`Project`, `Project::Version`, `VersionTag`, `GithubRelease`) lives in `lib/gempilot/` as first-class autoloaded classes. A `VersionTasks` class provides the rake integration. Generated gems add `gem "gempilot"` and `require "gempilot/version_tasks"`. The CLI `bump` command delegates to `rake version:bump` like `release` already delegates to `rake release`.

## Architecture

```
lib/gempilot/
  project.rb              — Gempilot::Project (gem introspection)
  project/
    version.rb            — Gempilot::Project::Version (semver value object)
  version_tag.rb          — Gempilot::VersionTag (git release ops)
  github_release.rb       — Gempilot::GithubRelease (github release ops)
  strict_shell.rb         — Gempilot::StrictShell (shared shell mixin)
  version_tasks.rb        — Gempilot::VersionTasks < Rake::TaskLib (entry point)
```

Only `VersionTasks` depends on Rake. The rest are plain Ruby domain objects that Zeitwerk autoloads normally. `VersionTasks` is ignored by Zeitwerk (requires Rake as a side effect) and loaded via explicit `require "gempilot/version_tasks"`.

## Files

### Create
| Path | Class |
|------|-------|
| `lib/gempilot/strict_shell.rb` | `Gempilot::StrictShell` |
| `lib/gempilot/project.rb` | `Gempilot::Project` |
| `lib/gempilot/project/version.rb` | `Gempilot::Project::Version` |
| `lib/gempilot/version_tag.rb` | `Gempilot::VersionTag` |
| `lib/gempilot/github_release.rb` | `Gempilot::GithubRelease` |
| `lib/gempilot/version_tasks.rb` | `Gempilot::VersionTasks` |

### Delete
| Path | Reason |
|------|--------|
| `rakelib/project.rb` | Moved to lib/gempilot/ |
| `rakelib/project_version.rb` | Moved to lib/gempilot/project/version.rb |
| `rakelib/version_tag.rb` | Moved to lib/gempilot/ |
| `rakelib/github_release.rb` | Moved to lib/gempilot/ |
| `rakelib/strict_shell.rb` | Moved to lib/gempilot/ |
| `rakelib/version.rake` | Replaced by VersionTasks |
| `data/templates/gem/rakelib/` | Entire directory (6 symlinks) |
| `data/templates/gem/lib/core_ext/` | Entire directory (2 symlinks) |

### Modify
| Path | Change |
|------|--------|
| `lib/gempilot.rb` | Add `LOADER.ignore` for `version_tasks.rb` |
| `gempilot.gemspec` | Add `warning` runtime dep, fix fallback glob |
| `Gemfile` | Remove `gem "warning"` |
| `Rakefile` | Use `require "gempilot/version_tasks"` + `Gempilot::VersionTasks.new` |
| `lib/gempilot/cli/commands/bump.rb` | Delegate to `rake version:bump[SEGMENT]` |
| `lib/gempilot/cli/commands/release.rb` | Delegate to `rake version:release` (already similar) |
| `data/templates/gem/Rakefile.erb` | Add require + VersionTasks.new |
| `data/templates/gem/Gemfile.erb` | Add `gem "gempilot", require: false` |
| `data/templates/gem/gemspec.erb` | Change fallback glob `{lib,exe,rakelib}` → `{lib,exe}` |
| `data/templates/gem/lib/gem_name.rb.erb` | Remove `LOADER.ignore("#{__dir__}/core_ext")` |
| `lib/gempilot/cli/gem_builder.rb` | Remove `render_version_rake`, `render_core_ext` + calls |
| Specs | Update require paths + class references |
| `test/gempilot/cli/create_command_test.rb` | Update assertions for new generated gem structure |

## Domain Model Changes

### `Project::Version#bump(segment)` — add segment support

Currently `next_version` only increments the last segment. Add `bump(segment = :patch)`:

```ruby
def bump(segment = :patch)
  major, minor, patch = value.split(".").map(&:to_i)
  new_value = case segment.to_sym
              when :major then "#{major + 1}.0.0"
              when :minor then "#{major}.#{minor + 1}.0"
              when :patch then "#{major}.#{minor}.#{patch + 1}"
              end
  with(value: new_value)
end
```

`next_version` stays as an alias for `bump(:patch)` for backwards compatibility with the existing specs.

### `version:bump` rake task — accept segment argument

```ruby
desc "Bump version (patch default, or rake version:bump[minor])"
task :bump, [:segment] do |_t, args|
  segment = (args[:segment] || :patch).to_sym
  old_version = project.version
  new_version = old_version.bump(segment)
  project.write_version!(old_version, new_version)
  project.refresh_version!
  puts "Version bumped from #{old_version.value} to #{project.version_value}"
end
```

### `Bump` CLI command — delegate to rake

Replace the 104-line implementation with a thin rake delegation (same pattern as `Release`):

```ruby
def run(segment = "patch")
  detect_gem_context
  validate_segment(segment)
  run_rake_bump(segment)
end

private

def run_rake_bump(segment)
  success = Bundler.with_unbundled_env do
    system("bundle", "exec", "rake", "version:bump[#{segment}]")
  end
  exit 1 unless success
end
```

## Tasks

### Task 1: Create domain classes in lib/gempilot/

Move and namespace the 5 domain classes + create `VersionTasks`. Each is a mechanical translation wrapping in `module Gempilot`. Add `Version#bump(segment)` method. Add `LOADER.ignore` for `version_tasks.rb` only (the rest autoload normally). Add `warning` to gemspec runtime deps.

### Task 2: Dogfood — switch gempilot's Rakefile

Add `require "gempilot/version_tasks"` + `Gempilot::VersionTasks.new`. Delete all 6 `rakelib/` files. Verify `rake -T version` and `rake version:current`.

### Task 3: Update specs

Change require paths and class references in all rakelib specs. Add spec for `Version#bump(:minor)` and `Version#bump(:major)`. Run specs.

### Task 4: Simplify CLI Bump command

Replace the 104-line implementation with rake delegation. Keep `validate_segment` for the CLI-side error message. Remove duplicate `VERSION_PATTERN`, `read_current_version`, `write_new_version`, `increment` methods.

### Task 5: Update templates + generator

- `Rakefile.erb`: add `require "gempilot/version_tasks"` + `Gempilot::VersionTasks.new`
- `Gemfile.erb`: add `gem "gempilot", require: false`
- `gemspec.erb`: change fallback glob to `{lib,exe}`
- `gem_name.rb.erb`: remove `LOADER.ignore("#{__dir__}/core_ext")`
- `gem_builder.rb`: remove `render_version_rake`, `render_core_ext` + calls
- Delete `data/templates/gem/rakelib/` and `data/templates/gem/lib/core_ext/`

### Task 6: Update create_command_test.rb

Remove assertions about rakelib/core_ext files in generated gems. Add assertions for Gemfile containing `gempilot` and Rakefile containing `VersionTasks`.

### Task 7: Integration test

Generate a test gem. Verify: no `rakelib/` support files, no `lib/core_ext/`, `gem "gempilot"` in Gemfile, `rake -T version` lists 12 tasks, `rake version:current` works, `bundle exec rake` passes.

## Verification

1. `bundle exec rake test spec` — gempilot suite passes
2. `bundle exec rubocop` — 0 offenses
3. `bundle exec rake -T version` — 12 tasks via the new require
4. `bundle exec rake version:bump[minor]` — segment argument works
5. `gempilot bump minor` — CLI delegates to rake
6. Generate a test gem — works end-to-end with gempilot as a Gemfile dependency
