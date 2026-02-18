---
name: using-command-kit
description: Use when building Ruby CLI applications with command_kit or command_mapper gems, structuring subcommands, adding options/arguments, generating files from ERB templates, or prompting users for input in Ruby
---

# Building Ruby CLIs with CommandKit + CommandMapper

CommandKit is a modular Ruby toolkit for building CLI commands with composable include-based modules. CommandMapper wraps external CLI tools with typed Ruby DSLs. Reference implementation: [Ronin](https://github.com/ronin-rb/ronin).

**Core principle:** Include only what you need. Never hand-roll what CommandKit already provides.

## Quick Reference

| Need | Module | Key Method |
|------|--------|------------|
| Subcommand dispatch | `Commands` | `command(name, klass)` |
| Auto-discover commands | `Commands::AutoLoad` | `AutoLoad.new(dir:, namespace:)` |
| Options | `Options` | `option :name, value: {type:}, desc:` |
| Arguments | `Arguments` | `argument :name, required:, desc:` |
| Prompt user | `Interactive` | `ask`, `ask_yes_or_no`, `ask_multiple_choice` |
| Colored output | `Colors` | `colors.green("text")` |
| ERB templates | `FileUtils` | `erb(source, dest)` |
| String inflection | `Inflector` | `camelize`, `underscore`, `demodularize` |
| Version flag | `Options::Version` | `version "1.0.0"` |
| Bug reports | `BugReport` | `bug_report_url "https://..."` |
| Tables | `Printing::Tables` | `print_table(rows, header:, border:)` |
| Pager | `Pager` | `pager { |io| io.puts data }` |

All modules prefixed `CommandKit::`.

## CLI Structure

```
exe/mytool                         # Thin entry (see BUNDLE_GEMFILE note below)
lib/mytool/cli.rb                  # Commands + AutoLoad
lib/mytool/cli/command.rb          # Base command (Colors, Interactive, BugReport)
lib/mytool/cli/commands/foo.rb     # Auto-discovered as "mytool foo"
data/templates/                    # ERB templates for generators
```

**exe entry point must set `BUNDLE_GEMFILE`** so it works from any directory:
```ruby
#!/usr/bin/env ruby
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)
require "bundler/setup"
require "mytool/cli"
MyTool::CLI.start
```

Without this, `require "bundler/setup"` fails with `Bundler::GemfileNotFound` when called from outside the project directory.

See `cli-example.rb` for complete CLI + base command + subcommand implementation.

## Generator Pattern

For file generation commands, build a Generator mixin with `template_dir`, `mkdir`, `erb`, `cp`, `sh` wrappers that print colored actions. See `generator-pattern.rb` for full implementation following Ronin's pattern.

Templates use instance variables set in `run()` via ERB binding:
```erb
module <%= @module_name %>
  VERSION = "0.1.0"
end
```

## Boolean Options with Negation

CommandKit does NOT auto-generate `--no-<name>` flags. Use OptionParser's `--[no-]` syntax via `long:`:

```ruby
# ❌ Only creates --verbose (no way to explicitly disable)
option :verbose, desc: "Enable verbose output"

# ✅ Creates both --verbose and --no-verbose
option :verbose, long: '--[no-]verbose', desc: "Enable verbose output"
```

With `--[no-]`, OptionParser passes `true` for `--verbose`, `false` for `--no-verbose`. When neither is passed, the key is absent from `options`. Use `options.has_key?(:verbose)` to detect "not provided" vs explicit choice.

## Interactive Prompting

Include `Interactive` in base Command. Prompt when args are missing:
```ruby
def run(name = nil)
  @name = name || ask("Name:", required: true)
  @test = options[:test] || ask_multiple_choice("Framework:", %w[minitest rspec])
  @git = options.fetch(:git) { ask_yes_or_no("Init git?", default: true) }
end
```

**`ask_multiple_choice` return values:**
- Array form: `ask_multiple_choice("Pick:", %w[minitest rspec])` → returns `String` (`"minitest"`)
- Hash form: `ask_multiple_choice("Pick:", {"minitest" => :minitest, "rspec" => :rspec})` → returns the **value** (`:minitest`), not the key

Use the Hash form when you need symbols or mapped values.

**Rich prompts** — print colored explanation before `ask()`:
```ruby
puts colors.bright_black("A short (one line) summary of what your gem does.")
ask(colors.green("Summary"), default: "A new Ruby gem")
```

Also: `ask_secret(prompt)`, `ask_multiline(prompt, terminator:)`.

## CommandMapper

Use `command_mapper` gem for typed interfaces to external CLI tools (bundler, git, etc.). Define subcommands, options with types, and arguments. Execute with `run_command`, `capture_command`, or inspect with `command_string`.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Hand-rolling inflection | `Inflector.camelize(name)` |
| No `examples` on commands | Always define `examples [...]` |
| Not prompting for missing args | Include `Interactive`, prompt in `run` |
| Multiple shell execution paths | Pick one: `system()`, `Open3`, or CommandMapper |
| Forgetting `bug_report_url` | One line in base Command, inherited everywhere |
| Skipping `description` | Always set - drives help and command summary |
| Expecting `--no-flag` to work | Must use `long: '--[no-]flag'` explicitly |
| Bare `require "bundler/setup"` in exe | Set `ENV["BUNDLE_GEMFILE"]` first |
