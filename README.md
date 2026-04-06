# Gempilot

A CLI toolkit for creating and managing Ruby gems with modern conventions.

Gempilot scaffolds production-ready gems with Zeitwerk autoloading, RuboCop,
GitHub Actions CI, and integrated version management. It also generates
classes, modules, and commands within existing gems.

## Installation

```bash
gem install gempilot
```

Requires Ruby >= 3.4.

## Quick Start

```bash
gempilot create my_gem
cd my_gem
bundle exec rake
```

This creates a fully configured gem with tests, linting, CI, and version
management — ready to develop.

## Commands

### `gempilot create`

Scaffold a new gem.

```bash
gempilot create my_gem
gempilot create --test rspec --exe my_gem
gempilot create --test minitest --no-git my_gem
```

Options:

| Option | Description | Default |
|--------|-------------|---------|
| `--test {minitest\|rspec}` | Test framework | prompted |
| `--[no-]exe` | Create executable in `exe/` | prompted |
| `--[no-]git` | Initialize git repo | prompted |
| `--branch NAME` | Git branch name | `master` |
| `--summary TEXT` | One-line gem description | prompted |
| `--author NAME` | Author name | `git config user.name` |
| `--email EMAIL` | Author email | `git config user.email` |
| `--ruby-version VER` | Minimum Ruby version | current Ruby |

All options are prompted interactively if omitted.

### `gempilot new`

Generate a class, module, or command in an existing gem. Run from the gem root.

```bash
gempilot new class MyGem::Services::Authentication
gempilot new module MyGem::Middleware
gempilot new command deploy
```

Creates the source file under `lib/` and a corresponding test file. For
commands, generates a CommandKit command class in `lib/<gem>/cli/commands/`.

### `gempilot destroy`

Remove a class, module, or command. Cleans up empty parent directories.

```bash
gempilot destroy class MyGem::Services::Authentication
gempilot destroy command deploy
```

### `gempilot bump`

Bump the version in `lib/<gem>/version.rb`.

```bash
gempilot bump          # patch (default)
gempilot bump minor
gempilot bump major
```

### `gempilot release`

Delegates to `rake release` to build and push the gem.

### `gempilot console`

Delegates to `bin/console` for an interactive IRB session with the gem loaded.

## Generated Gem Features

Every gem scaffolded by `gempilot create` includes:

- **Zeitwerk autoloading** with `LOADER` constant and `rake zeitwerk:validate`
- **Test framework** — Minitest or RSpec, with a Zeitwerk eager-load test
- **RuboCop** with `rubocop-claude`, `rubocop-performance`, `rubocop-rake`, and
  framework-specific plugins (`rubocop-minitest` or `rubocop-rspec`)
- **GitHub Actions CI** running tests and RuboCop
- **Version management** rake tasks (see below)
- **`bin/console`** and **`bin/setup`** scripts
- **Gemspec** with `git ls-files` and glob fallback, MFA required for RubyGems

### Version Management Tasks

Generated gems include rake tasks for the full version lifecycle:

| Task | Description |
|------|-------------|
| `rake version:current` | Display the current version |
| `rake version:bump` | Increment the patch version |
| `rake version:commit` | Commit the version file change |
| `rake version:tag` | Create a git tag for the version |
| `rake version:untag` | Delete the version git tag |
| `rake version:reset` | Reset the last version bump commit |
| `rake version:revert` | Revert the last version bump commit |
| `rake version:release` | Bump, commit, and tag (combined) |
| `rake version:unrelease` | Untag and reset (combined) |
| `rake version:github:release` | Push and create a GitHub release |
| `rake version:github:unrelease` | Delete the GitHub release |
| `rake version:github:list` | List GitHub releases |

## Development

```bash
git clone https://github.com/gillisd/gempilot.git
cd gempilot
bundle install
bundle exec rake
```

`rake` runs the Minitest suite, RSpec suite, and RuboCop.

## License

MIT License. See [LICENSE.txt](LICENSE.txt).
