# Gempilot

A CLI for creating and managing Ruby gems — like `bundle gem`, but with generators.

## Why gempilot?

`bundle gem` scaffolds a gem and then you're on your own. Gempilot keeps helping:

- **Generators** — `gempilot new class/module/command` creates files with proper Zeitwerk naming, module nesting, and matching test files. `gempilot destroy` reverses them cleanly.
- **Zeitwerk autoloading** — generated gems use Zeitwerk out of the box with a validation rake task.
- **Version management** — `gempilot bump patch/minor/major` edits `version.rb` directly. Generated gems include rake tasks for version bumps and tagged releases.
- **CI included** — every gem gets a GitHub Actions workflow with tests and RuboCop.
- **Test framework choice** — pick minitest or rspec at creation time; templates adapt accordingly.

## Installation

```bash
gem install gempilot
```

## Quick start

```bash
# Create a new gem
gempilot create my_gem

cd my_gem

# Generate a class with a matching test file
gempilot new class models/user

# Generate a command (CommandKit subcommand)
gempilot new command import

# Remove a generated file and its test
gempilot destroy class models/user

# Bump the version
gempilot bump minor

# Run tests, then release
bundle exec rake test
gempilot release
```

## Commands

| Command | Description |
|---------|-------------|
| `gempilot create NAME` | Scaffold a new gem with Zeitwerk, CI, and version tasks |
| `gempilot new TYPE NAME` | Generate a class, module, or command in an existing gem |
| `gempilot destroy TYPE NAME` | Remove a generated class, module, or command |
| `gempilot bump [LEVEL]` | Bump the gem version (patch, minor, or major) |
| `gempilot release` | Release the gem to RubyGems (delegates to `rake release`) |
| `gempilot console` | Start an interactive console with the gem loaded |

Run `gempilot COMMAND --help` for detailed usage on any command.

## What a generated gem includes

- [Zeitwerk](https://github.com/fxn/zeitwerk) autoloading with `rake zeitwerk:validate`
- Test framework (minitest or rspec) with a Zeitwerk validation test
- RuboCop with framework-appropriate plugins
- GitHub Actions CI (`.github/workflows/ci.yml`)
- Version management rake tasks (`version:current`, `version:bump`, `version:commit`, `release:full`)
- `git ls-files`-based gemspec with `Dir.glob` fallback for non-git repos

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
