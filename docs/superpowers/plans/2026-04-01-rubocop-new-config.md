# RuboCop New Config Transition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the legacy rubocop config (copied from the `remap` project) with the new opinionated config from `new_rubocop.yml`, for both gempilot's own `.rubocop.yml` and the generated-gem template at `data/templates/gem/dotfiles/rubocop.yml.erb`.

**Architecture:** The new config introduces `rubocop-claude` as a plugin, enforces stricter metrics (method length, block length, ABC size), enables `Style/Documentation`, removes `frozen_string_literal` comments, and adopts pipeline-style Ruby (multiline block chains, braces for functional transforms). The template must conditionally include `rubocop-minitest` or `rubocop-rspec` cops. The project itself uses minitest, so the project config uses `rubocop-minitest`. After swapping configs, we auto-correct what we can and manually fix the rest.

**Tech Stack:** RuboCop, rubocop-claude, rubocop-performance, rubocop-minitest/rubocop-rspec

---

## File Map

| Action | File | Purpose |
|--------|------|---------|
| Modify | `Gemfile` | Add `rubocop-claude`, remove `rubocop-md` |
| Replace | `.rubocop.yml` | New config adapted for minitest |
| Replace | `data/templates/gem/dotfiles/rubocop.yml.erb` | New config as ERB with minitest/rspec conditionals |
| Modify | `data/templates/gem/Gemfile.erb` | Add `rubocop-claude`, remove `rubocop-md` |
| Delete | `new_rubocop.yml` | Source material, no longer needed once integrated |
| Modify | `lib/gempilot/cli/commands/bump.rb` | Fix metrics offenses, move constant above `private` |
| Modify | `lib/gempilot/cli/commands/console.rb` | Fix method length |
| Modify | `lib/gempilot/cli/commands/create.rb` | Decompose `run` method (112 lines -> extracted helpers) |
| Modify | `lib/gempilot/cli/commands/destroy.rb` | Fix method length + ABC size |
| Modify | `lib/gempilot/cli/commands/new.rb` | Fix method length + ABC size |
| Modify | `lib/gempilot/cli/generator.rb` | Fix `Style/OptionalArguments` |
| Modify | `lib/gempilot/cli.rb` | Add rdoc class documentation |
| Modify | `lib/gempilot/cli/command.rb` | Add rdoc class documentation |
| Modify | `lib/gempilot/cli/gem_context.rb` | Add rdoc module documentation |
| Modify | `lib/gempilot/cli/generator.rb` | Add rdoc module documentation |
| Modify | All `lib/gempilot/cli/commands/*.rb` | Add rdoc class documentation |
| Modify | `test/support/environment.rb` | Fix `Security/Open`, `Naming/PredicateMethod`, `Style/ItAssignment`, method length |
| Modify | `test/gempilot/cli/create_command_test.rb` | Fix test method length |
| Modify | `test/gempilot/cli/destroy_command_test.rb` | Fix test method length |

---

## Task 1: Update Gemfile and Install Dependencies

**Files:**
- Modify: `Gemfile`

This adds `rubocop-claude` to the project's dependencies and removes `rubocop-md` (the new config doesn't use it). The `rubocop-rake` gem stays since tests need rake tasks.

- [ ] **Step 1: Update Gemfile**

Replace the rubocop block in `Gemfile` (lines 5-9):

```ruby
# old
gem "rubocop"
gem "rubocop-md"
gem "rubocop-minitest"
gem "rubocop-performance"
gem "rubocop-rake"
```

with:

```ruby
gem "rubocop"
gem "rubocop-claude"
gem "rubocop-minitest"
gem "rubocop-performance"
gem "rubocop-rake"
```

- [ ] **Step 2: Bundle install**

Run: `bundle install`
Expected: Resolves successfully, `rubocop-claude` appears in `Gemfile.lock`.

- [ ] **Step 3: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "Add rubocop-claude gem, drop rubocop-md"
```

---

## Task 2: Replace Project .rubocop.yml

**Files:**
- Replace: `.rubocop.yml`

Adapt `new_rubocop.yml` for the project: swap `rubocop-rspec` for `rubocop-minitest`, replace RSpec cops with Minitest equivalents, set `TargetRubyVersion` to the system Ruby minor version, and add project-specific exclusions.

- [ ] **Step 1: Write the new `.rubocop.yml`**

```yaml
# ===========================================================================
# RuboCop Configuration
#
# Base: Stock RuboCop defaults
# AI guardrails: rubocop-claude plugin (all Claude/ cops + stricter metrics)
# Performance: rubocop-performance (with chain-hostile cops disabled)
#
# Philosophy: idiomatic Ruby, pipeline-style chaining, strict for AI agents,
# readable for humans.
# ===========================================================================

plugins:
  - rubocop-claude
  - rubocop-minitest
  - rubocop-performance
  - rubocop-rake

AllCops:
  NewCops: enable
  TargetRubyVersion: 3.4
  Exclude:
    - bin/*
    - vendor/**/*
    - data/templates/**/*

# ===========================================================================
# Overrides from stock — personal style preferences
# ===========================================================================

# Double quotes everywhere. One less decision to make.
Style/StringLiterals:
  EnforcedStyle: double_quotes

Style/StringLiteralsInInterpolation:
  EnforcedStyle: double_quotes

# Frozen string literal is transitional cruft. Ruby 3.4 has chilled strings,
# full default freeze is coming in a future Ruby.
Style/FrozenStringLiteralComment:
  EnforcedStyle: never

# Pipeline style. Chaining multi-line blocks is the whole point.
Style/MultilineBlockChain:
  Enabled: false

# Block delimiters are a taste call. Pipeline code uses braces for chaining,
# do/end for side effects. No cop captures this nuance.
Style/BlockDelimiters:
  Enabled: false

# Write arrays like arrays.
Style/WordArray:
  Enabled: false

Style/SymbolArray:
  Enabled: false

# Argument indentation: consistent 2-space indent, not aligned to first arg.
Layout/FirstArgumentIndentation:
  EnforcedStyle: consistent

# Dot-aligned chaining. Dots form a visual column.
Layout/MultilineMethodCallIndentation:
  EnforcedStyle: aligned

# ===========================================================================
# Overrides from rubocop-claude — loosen where pipeline style conflicts
# ===========================================================================

Claude/NoOverlyDefensiveCode:
  MaxSafeNavigationChain: 2

Style/SafeNavigation:
  MaxChainLength: 2

# Allow `return a, b` for tuple-style returns.
Style/RedundantReturn:
  AllowMultipleReturnValues: true

# ===========================================================================
# Overrides from rubocop-performance — disable chain-hostile cops
# ===========================================================================

Performance/ChainArrayAllocation:
  Enabled: false

Performance/MapMethodChain:
  Enabled: false

# ===========================================================================
# Additional tightening — not set by stock or rubocop-claude
# ===========================================================================

# Short blocks push toward small chained steps instead of fat lambdas.
Metrics/BlockLength:
  Max: 8
  CountAsOne:
    - array
    - hash
    - heredoc
    - method_call
  AllowedMethods:
    - command
    - describe
    - context
    - shared_examples
    - shared_examples_for
    - shared_context
  Exclude:
    - "test/**/*"

# Minitest tests legitimately define many assertions per test method
# when testing multi-file generators. Default is 3, too tight.
Minitest/MultipleAssertions:
  Max: 10

# Anonymous forwarding (*, **, &) breaks TruffleRuby, JRuby, and
# Ruby < 3.2. Named args are explicit and portable.
Style/ArgumentsForwarding:
  Enabled: false

# Explicit begin/rescue/end is clearer than implicit method-body rescue.
Style/RedundantBegin:
  Enabled: false

# Classes get rdoc. Run `rake rdoc` and keep it honest.
Style/Documentation:
  Enabled: true
  Exclude:
    - "test/**/*"

# Trailing commas in multiline literals and arguments.
Style/TrailingCommaInArrayLiteral:
  EnforcedStyleForMultiline: comma

Style/TrailingCommaInHashLiteral:
  EnforcedStyleForMultiline: comma

Style/TrailingCommaInArguments:
  EnforcedStyleForMultiline: comma
```

Key adaptations from `new_rubocop.yml`:
- `rubocop-rspec` -> `rubocop-minitest`
- Added `rubocop-rake` (project uses it)
- RSpec cops -> `Minitest/MultipleAssertions: Max: 10`
- `TargetRubyVersion: 3.4` (project targets 3.4, not 4.0)
- Added `Exclude: data/templates/**/*` (ERB templates aren't valid Ruby)
- Added `Exclude: test/**/*` for `Metrics/BlockLength` and `Style/Documentation`

- [ ] **Step 2: Run rubocop to verify config loads**

Run: `bundle exec rubocop --format offenses`
Expected: Config loads without errors. Offenses listed (we'll fix them in later tasks).

- [ ] **Step 3: Commit**

```bash
git add .rubocop.yml
git commit -m "Replace legacy rubocop config with new opinionated config"
```

---

## Task 3: Auto-correct Safe Offenses

**Files:**
- All `lib/**/*.rb` and `test/**/*.rb` files

Run rubocop auto-correct to fix all the safe+unsafe correctable offenses (trailing commas, string literals, guard clauses, layout, etc.). This handles ~200 of the 280 offenses.

- [ ] **Step 1: Run auto-correct**

Run: `bundle exec rubocop -A`
Expected: Many offenses auto-corrected.

- [ ] **Step 2: Run tests to verify nothing broke**

Run: `bundle exec rake test`
Expected: All tests pass.

- [ ] **Step 3: Run rubocop to see remaining offenses**

Run: `bundle exec rubocop --format offenses`
Expected: Only non-auto-correctable offenses remain (Metrics/*, Style/Documentation, Security/Open, etc.).

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "Auto-correct rubocop offenses under new config"
```

---

## Task 4: Add rdoc Documentation to All Classes and Modules

**Files:**
- Modify: `lib/gempilot/cli.rb`
- Modify: `lib/gempilot/cli/command.rb`
- Modify: `lib/gempilot/cli/commands/bump.rb`
- Modify: `lib/gempilot/cli/commands/console.rb`
- Modify: `lib/gempilot/cli/commands/create.rb`
- Modify: `lib/gempilot/cli/commands/destroy.rb`
- Modify: `lib/gempilot/cli/commands/new.rb`
- Modify: `lib/gempilot/cli/commands/release.rb`
- Modify: `lib/gempilot/cli/gem_context.rb`
- Modify: `lib/gempilot/cli/generator.rb`

Add `##` rdoc blocks above every class/module that `Style/Documentation` flags. No blank line between the doc block and the `class`/`module` keyword.

- [ ] **Step 1: Read each flagged file and add documentation**

Use rdoc style (not YARD). Each doc block describes what the class/module represents:

For `lib/gempilot/cli.rb`:
```ruby
##
# Top-level command router for the gempilot CLI.
# Uses CommandKit::Commands::AutoLoad to map subcommands
# from the +commands/+ directory.
class CLI
```

For `lib/gempilot/cli/command.rb`:
```ruby
##
# Base command class for all gempilot subcommands.
# Provides color output, interactive prompts, and bug reporting.
class Command < CommandKit::Command
```

For `lib/gempilot/cli/commands/bump.rb`:
```ruby
##
# Bumps the VERSION constant in an existing gem's +version.rb+.
# Supports patch (default), minor, and major increments.
class Bump < Command
```

For `lib/gempilot/cli/commands/console.rb`:
```ruby
##
# Launches an IRB session via the gem's +bin/console+ script.
class Console < Command
```

For `lib/gempilot/cli/commands/create.rb`:
```ruby
##
# Scaffolds a new gem with Zeitwerk autoloading, test framework,
# RuboCop config, CI workflow, and version management rake tasks.
class Create < Command
```

For `lib/gempilot/cli/commands/destroy.rb`:
```ruby
##
# Removes a class, module, or command from an existing gem,
# including its source file, test file, and empty parent directories.
class Destroy < Command
```

For `lib/gempilot/cli/commands/new.rb`:
```ruby
##
# Generates a new class, module, or command inside an existing gem.
# Creates the source file with proper Zeitwerk-compatible nesting
# and a corresponding test file.
class New < Command
```

For `lib/gempilot/cli/commands/release.rb`:
```ruby
##
# Delegates to +rake release+ to build and push the gem to RubyGems.
class Release < Command
```

For `lib/gempilot/cli/gem_context.rb`:
```ruby
##
# Shared context for commands that operate inside an existing gem.
# Detects the gem root, parses the gemspec for gem and module names,
# and determines the active test framework.
module GemContext
```

For `lib/gempilot/cli/generator.rb`:
```ruby
##
# File generation utilities for scaffolding gems and components.
# Provides +mkdir+, +touch+, +create_file+, +erb+, +sh+, and
# related helpers used by the Create and New commands.
module Generator
```

For `lib/gempilot/cli/generator.rb` (ClassMethods):
```ruby
##
# Class-level helpers for Generator, including +template_dir+
# resolution.
module ClassMethods
```

- [ ] **Step 2: Run rubocop to verify Style/Documentation is clean**

Run: `bundle exec rubocop --only Style/Documentation`
Expected: 0 offenses.

- [ ] **Step 3: Run tests**

Run: `bundle exec rake test`
Expected: All pass.

- [ ] **Step 4: Commit**

```bash
git add lib/
git commit -m "Add rdoc documentation to all classes and modules"
```

---

## Task 5: Decompose Create#run (112 lines)

**Files:**
- Modify: `lib/gempilot/cli/commands/create.rb`

The `run` method in Create is 112 lines -- the single worst offender. Extract logical sections into private helper methods. The method currently does: option collection (interactive prompts), directory creation, template rendering, git init, bundle install. Each becomes its own method.

- [ ] **Step 1: Read the current file**

Run: Read `lib/gempilot/cli/commands/create.rb`

- [ ] **Step 2: Extract helper methods**

The `run` method should become an orchestrator that calls:
- `collect_options` — interactive prompts and option resolution
- `create_directory_structure` — mkdir calls
- `render_templates` — ERB rendering calls
- `render_test_templates` — test-framework-specific templates
- `initialize_git_repo` — git init + initial commit
- `run_bundle_install` — bundler setup

Each extracted method should be under 10 lines. Keep them `private`.

- [ ] **Step 3: Run rubocop on the file**

Run: `bundle exec rubocop lib/gempilot/cli/commands/create.rb`
Expected: No Metrics/MethodLength, Metrics/AbcSize, or Metrics/ClassLength offenses.

If ClassLength (100) is still exceeded after extraction, the class likely needs a collaborator object (e.g., `Gempilot::CLI::GemScaffold` or similar). Assess and extract if needed.

- [ ] **Step 4: Run tests**

Run: `bundle exec rake test`
Expected: All pass.

- [ ] **Step 5: Commit**

```bash
git add lib/gempilot/cli/commands/create.rb
git commit -m "Decompose Create#run into focused helper methods"
```

---

## Task 6: Fix Remaining Metrics Offenses in Commands

**Files:**
- Modify: `lib/gempilot/cli/commands/bump.rb`
- Modify: `lib/gempilot/cli/commands/console.rb`
- Modify: `lib/gempilot/cli/commands/destroy.rb`
- Modify: `lib/gempilot/cli/commands/new.rb`

Each file has 1-3 methods over the 10-line or ABC-size limit. Extract small helpers.

- [ ] **Step 1: Read and fix bump.rb**

Offenses:
- `run` (14 lines, ABC 29) — extract version file discovery and version display into helpers
- `bump_version` (17 lines, ABC 17.5) — extract regex matching into a helper
- `Lint/UselessConstantScoping` — move `VERSION_PATTERN` above `private`
- `Metrics/CyclomaticComplexity` and `PerceivedComplexity` on `cli_arg_version` — simplify with a lookup hash

- [ ] **Step 2: Read and fix console.rb**

Offenses:
- `run` (11 lines, ABC 22) — minor, extract validation checks

- [ ] **Step 3: Read and fix destroy.rb**

Offenses:
- `run` (18 lines, ABC 21.7) — extract prompting and dispatch logic
- `destroy_class` (13 lines, ABC 21.5) — extract file removal logic

- [ ] **Step 4: Read and fix new.rb**

Offenses:
- `run` (18 lines, ABC 21.7) — extract prompting and dispatch logic
- `build_nested_source` (11 lines, ABC 17.8) — minor, extract if possible
- `add_class` (11 lines, ABC 25.7) — extract template rendering
- `add_module` (similar) — extract template rendering
- `add_command` (12 lines, ABC 22.8) — extract template rendering
- `add_test_file` (26 lines, ABC 20.5) — split minitest vs rspec paths

- [ ] **Step 5: Run rubocop on all command files**

Run: `bundle exec rubocop lib/gempilot/cli/commands/`
Expected: 0 Metrics offenses.

- [ ] **Step 6: Run tests**

Run: `bundle exec rake test`
Expected: All pass.

- [ ] **Step 7: Commit**

```bash
git add lib/gempilot/cli/commands/
git commit -m "Fix metrics offenses in command classes"
```

---

## Task 7: Fix Remaining Non-Metrics Offenses

**Files:**
- Modify: `lib/gempilot/cli/generator.rb` — `Style/OptionalArguments`
- Modify: `test/support/environment.rb` — `Security/Open`, `Naming/PredicateMethod`, `Style/ItAssignment`

- [ ] **Step 1: Fix generator.rb**

The `Style/OptionalArguments` offense is at line 38. An optional positional argument appears before a required one. Reorder or convert to keyword arguments.

- [ ] **Step 2: Fix test/support/environment.rb**

- `Security/Open` at line 126: Replace `open(url)` with `URI.open(url)` or `File.open(path)` as appropriate.
- `Naming/PredicateMethod` at line 226: Rename predicate method to end with `?`.
- `Style/ItAssignment` at line 89: Rename block parameter from `it` to something else.

- [ ] **Step 3: Fix test method length offenses**

Read `test/gempilot/cli/create_command_test.rb` and `test/gempilot/cli/destroy_command_test.rb`. Extract shared setup into helper methods or split long test methods into focused assertions.

- [ ] **Step 4: Run rubocop**

Run: `bundle exec rubocop`
Expected: 0 offenses, 0 errors.

- [ ] **Step 5: Run tests**

Run: `bundle exec rake test`
Expected: All pass.

- [ ] **Step 6: Commit**

```bash
git add lib/gempilot/cli/generator.rb test/
git commit -m "Fix remaining rubocop offenses (security, naming, test length)"
```

---

## Task 8: Replace Template rubocop.yml.erb

**Files:**
- Replace: `data/templates/gem/dotfiles/rubocop.yml.erb`
- Modify: `data/templates/gem/Gemfile.erb`

The template must produce a valid `.rubocop.yml` for both minitest and rspec gems. Use ERB conditionals for test-framework-specific sections.

- [ ] **Step 1: Write the new template**

```erb
# ===========================================================================
# RuboCop Configuration
#
# Base: Stock RuboCop defaults
# AI guardrails: rubocop-claude plugin (all Claude/ cops + stricter metrics)
# Performance: rubocop-performance (with chain-hostile cops disabled)
#
# Philosophy: idiomatic Ruby, pipeline-style chaining, strict for AI agents,
# readable for humans.
# ===========================================================================

plugins:
  - rubocop-claude
<% if @test_framework == :minitest -%>
  - rubocop-minitest
<% elsif @test_framework == :rspec -%>
  - rubocop-rspec
<% end -%>
  - rubocop-performance
  - rubocop-rake

AllCops:
  NewCops: enable
  TargetRubyVersion: <%= minor_version_for @ruby_version %>
  Exclude:
    - bin/*
    - vendor/**/*
<% if @hyphenated -%>
    - lib/<%= @gem_name %>.rb
<% end -%>

# ===========================================================================
# Overrides from stock — personal style preferences
# ===========================================================================

# Double quotes everywhere. One less decision to make.
Style/StringLiterals:
  EnforcedStyle: double_quotes

Style/StringLiteralsInInterpolation:
  EnforcedStyle: double_quotes

# Frozen string literal is transitional cruft. Ruby 3.4 has chilled strings,
# full default freeze is coming in a future Ruby.
Style/FrozenStringLiteralComment:
  EnforcedStyle: never

# Pipeline style. Chaining multi-line blocks is the whole point.
Style/MultilineBlockChain:
  Enabled: false

# Block delimiters are a taste call. Pipeline code uses braces for chaining,
# do/end for side effects. No cop captures this nuance.
Style/BlockDelimiters:
  Enabled: false

# Write arrays like arrays.
Style/WordArray:
  Enabled: false

Style/SymbolArray:
  Enabled: false

# Argument indentation: consistent 2-space indent, not aligned to first arg.
Layout/FirstArgumentIndentation:
  EnforcedStyle: consistent

# Dot-aligned chaining. Dots form a visual column.
Layout/MultilineMethodCallIndentation:
  EnforcedStyle: aligned

# ===========================================================================
# Overrides from rubocop-claude — loosen where pipeline style conflicts
# ===========================================================================

Claude/NoOverlyDefensiveCode:
  MaxSafeNavigationChain: 2

Style/SafeNavigation:
  MaxChainLength: 2

# Allow `return a, b` for tuple-style returns.
Style/RedundantReturn:
  AllowMultipleReturnValues: true

# ===========================================================================
# Overrides from rubocop-performance — disable chain-hostile cops
# ===========================================================================

Performance/ChainArrayAllocation:
  Enabled: false

Performance/MapMethodChain:
  Enabled: false

# ===========================================================================
# Additional tightening — not set by stock or rubocop-claude
# ===========================================================================

# Short blocks push toward small chained steps instead of fat lambdas.
Metrics/BlockLength:
  Max: 8
  CountAsOne:
    - array
    - hash
    - heredoc
    - method_call
  AllowedMethods:
    - command
<% if @test_framework == :minitest -%>
    - test
<% elsif @test_framework == :rspec -%>
    - describe
    - context
    - shared_examples
    - shared_examples_for
    - shared_context
<% end -%>

<% if @test_framework == :minitest -%>
# Minitest tests can legitimately need many assertions per method
# when verifying multi-step operations.
Minitest/MultipleAssertions:
  Max: 10
<% elsif @test_framework == :rspec -%>
# Shared test contexts legitimately define many helpers.
RSpec/MultipleMemoizedHelpers:
  Max: 10
<% end -%>

# Anonymous forwarding (*, **, &) breaks TruffleRuby, JRuby, and
# Ruby < 3.2. Named args are explicit and portable.
Style/ArgumentsForwarding:
  Enabled: false

# Explicit begin/rescue/end is clearer than implicit method-body rescue.
Style/RedundantBegin:
  Enabled: false

# Classes get rdoc.
Style/Documentation:
  Enabled: true
  Exclude:
<% if @test_framework == :minitest -%>
    - "test/**/*"
<% elsif @test_framework == :rspec -%>
    - "spec/**/*"
<% end -%>

# Trailing commas in multiline literals and arguments.
Style/TrailingCommaInArrayLiteral:
  EnforcedStyleForMultiline: comma

Style/TrailingCommaInHashLiteral:
  EnforcedStyleForMultiline: comma

Style/TrailingCommaInArguments:
  EnforcedStyleForMultiline: comma

<% if @test_framework == :rspec -%>
# ===========================================================================
# RSpec — rubocop-rspec overrides
# ===========================================================================

# Not every describe block wraps a class.
RSpec/DescribeClass:
  Enabled: false

# Subject placement is a readability call, not a rule.
RSpec/LeadingSubject:
  Enabled: false

# Block style for expect { }.to change { } reads like a sentence.
RSpec/ExpectChange:
  EnforcedStyle: block

RSpec/NamedSubject:
  Enabled: false

# have_file_content matcher accepts a filename string in expect()
RSpec/ExpectActual:
  Enabled: false
<% end -%>
```

- [ ] **Step 2: Update Gemfile.erb**

Replace the rubocop section in `data/templates/gem/Gemfile.erb`:

```erb
gem "rubocop"
gem "rubocop-claude"
<% if @test_framework == :minitest -%>
gem "rubocop-minitest"
<% end -%>
gem "rubocop-performance"
gem "rubocop-rake"
<% if @test_framework == :rspec -%>
gem "rubocop-rspec"
<% end -%>
```

Note: `rubocop-md` is removed (not in the new config).

- [ ] **Step 3: Commit**

```bash
git add data/templates/gem/dotfiles/rubocop.yml.erb data/templates/gem/Gemfile.erb
git commit -m "Update gem templates to use new rubocop config with rubocop-claude"
```

---

## Task 9: Delete new_rubocop.yml and Verify

**Files:**
- Delete: `new_rubocop.yml`

- [ ] **Step 1: Delete the source file**

```bash
git rm new_rubocop.yml
```

- [ ] **Step 2: Run full rubocop**

Run: `bundle exec rubocop`
Expected: 0 offenses.

- [ ] **Step 3: Run full test suite**

Run: `bundle exec rake test`
Expected: All tests pass.

- [ ] **Step 4: Verify a generated gem works with the new template**

Run a quick smoke test: generate a test gem with each framework and confirm `rubocop` loads cleanly in each:

```bash
cd /tmp
gempilot create --test minitest test_mini_gem
cd test_mini_gem && bundle install && bundle exec rubocop --format offenses
cd /tmp
gempilot create --test rspec test_rspec_gem
cd test_rspec_gem && bundle install && bundle exec rubocop --format offenses
```

Expected: Both gems load rubocop config without errors and have 0 offenses on the generated scaffold.

- [ ] **Step 5: Commit**

```bash
git rm new_rubocop.yml
git commit -m "Remove new_rubocop.yml — fully integrated into project and templates"
```

---

## Decision Log

| Decision | Rationale |
|----------|-----------|
| Drop `rubocop-md` | New config doesn't use it; markdown linting is low-value for this project |
| Keep `rubocop-rake` | Project and generated gems both define rake tasks |
| `TargetRubyVersion: 3.4` for project | Gempilot targets Ruby 3.4 per gemspec |
| `Exclude: data/templates/**/*` | ERB templates contain `<%= %>` tags that aren't valid Ruby |
| `Exclude: test/**/*` for BlockLength | Test methods naturally exceed 8-line block limits |
| `Exclude: test/**/*` for Documentation | Test classes don't need rdoc |
| `Minitest/MultipleAssertions: Max: 10` | Generator tests legitimately assert many file-system outcomes per test |
| `Metrics/BlockLength` AllowedMethods differ per framework | minitest uses `test`, rspec uses `describe`/`context`/`shared_*` |
