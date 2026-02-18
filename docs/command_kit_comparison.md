# Gempilot vs Ronin: CommandKit Usage Comparison

## How Gempilot Uses CommandKit

### Current Usage (after restructuring)

| CommandKit Module | Used? | Where |
|---|---|---|
| `CommandKit::Commands` | Yes | `Gempilot::CLI` - top-level command dispatcher |
| `CommandKit::Commands::AutoLoad` | Yes | `Gempilot::CLI` - auto-discovers commands from `cli/commands/` |
| `CommandKit::Options::Version` | Yes | `Gempilot::CLI` - `--version` flag |
| `CommandKit::Command` | Yes | `Gempilot::CLI::Command` - base class for all commands |
| `CommandKit::Colors` | Yes | `Gempilot::CLI::Command` and `Gempilot::CLI::Generator` |
| `CommandKit::FileUtils` | Yes | `Gempilot::CLI::Generator` - `erb()` method |
| `CommandKit::Options` | Yes | `Commands::New` - all option definitions (implicit via Command) |
| `CommandKit::Arguments` | Yes | `Commands::New` - `gem_name` argument (implicit via Command) |
| `CommandKit::Inflector` | **No** | Hand-rolled `inflect_module` in `Commands::New` instead |
| `CommandKit::Interactive` | **No** | Not included in base Command |
| `CommandKit::Description` | Yes | `Commands::New` - `description "Create a new gem"` |
| `CommandKit::Usage` | Yes | `Commands::New` - `usage "[options] GEM_NAME"` |
| `CommandKit::Printing` | Yes | Implicit via Command |
| `CommandKit::Printing::Indent` | **No** | |
| `CommandKit::Printing::Fields` | **No** | |
| `CommandKit::Printing::Lists` | **No** | |
| `CommandKit::Printing::Tables` | **No** | |
| `CommandKit::Terminal` | **No** | |
| `CommandKit::Pager` | **No** | |
| `CommandKit::OS` | **No** | |
| `CommandKit::XDG` | **No** | |
| `CommandKit::BugReport` | **No** | |
| `CommandKit::Help::Man` | **No** | |
| `CommandKit::Edit` | **No** | |
| `CommandKit::Examples` | **No** | No examples defined on any command |
| `CommandKit::ExceptionHandler` | Yes | Implicit via Command |

### What Gempilot Hand-Rolls Instead of Using CommandKit

1. **Inflector** - `Commands::New#inflect_module` (line 113-115) does:
   ```ruby
   def inflect_module(name)
     name.split(/[-_]/).map(&:capitalize).join
   end
   ```
   Should use `CommandKit::Inflector.camelize(name)` which handles the same transformation plus edge cases (e.g., `/` to `::` for nested modules).

2. **Generator module** - `Gempilot::CLI::Generator` reimplements ronin-core's Generator pattern. This is intentional (own implementation, no ronin-core dependency), but it duplicates logic that `CommandKit::FileUtils` already partly provides (`erb` method). The Generator adds `print_action`, `mkdir`, `cp`, `sh`, `touch`, `chmod` wrappers with colored output.

3. **Shell execution** - `Gempilot::Commands#sh` uses a custom `Runner` class with PTY/Open3 pipeline for command execution. The Generator module has its own simpler `sh` that calls `system()`. Two different shell execution paths exist.

---

## How Ronin Uses CommandKit (Reference Implementation)

### Module Usage

| CommandKit Module | Used? | Where |
|---|---|---|
| `CommandKit::Commands` | Yes | `Ronin::CLI` |
| `CommandKit::Commands::AutoLoad` | Yes | `Ronin::CLI`, `Commands::New`, and many others |
| `CommandKit::Options::Version` | Yes | `Ronin::CLI` |
| `CommandKit::Command` | Yes (via ronin-core) | `Core::CLI::Command` base class |
| `CommandKit::Colors` | Yes | `Core::CLI::Generator`, syntax highlighting |
| `CommandKit::FileUtils` | Yes | `Core::CLI::Generator` |
| `CommandKit::Options` | Yes | Every command |
| `CommandKit::Arguments` | Yes | Every command |
| `CommandKit::Interactive` | **No** | Not used in ronin itself |
| `CommandKit::Description` | Yes | Every command |
| `CommandKit::Usage` | Yes | Every command |
| `CommandKit::Examples` | Yes | Most commands have examples |
| `CommandKit::Printing` | Yes | Implicit via Command |
| `CommandKit::Printing::Indent` | Yes | Output formatting |
| `CommandKit::Printing::Tables` | Yes | Database query output |
| `CommandKit::Terminal` | Yes | Width-aware output |
| `CommandKit::Pager` | Yes | Long output paging |
| `CommandKit::OS` | Yes | OS-specific behavior |
| `CommandKit::BugReport` | Yes | `Core::CLI::Command` base class |
| `CommandKit::Help::Man` | Yes | Every command has `man_page` |
| `CommandKit::Inflector` | Yes | Used internally for command name derivation |

### Ronin Patterns Worth Adopting

1. **Every command has `examples`** - Ronin defines usage examples on almost every command:
   ```ruby
   examples [
     'project foo',
     'script foo.rb'
   ]
   ```

2. **`bug_report_url` on base command** - Set once, inherited everywhere:
   ```ruby
   class Command < Core::CLI::Command
     bug_report_url 'https://github.com/ronin-rb/ronin/issues/new'
   end
   ```

3. **Man pages** - Every command declares `man_page 'ronin-command.1'` for full documentation.

4. **Nested AutoLoad** - The `new` command is itself a Commands container with AutoLoad:
   ```ruby
   class New < Command
     include CommandKit::Commands::AutoLoad.new(
       dir:       "#{__dir__}/new",
       namespace: "#{self}"
     )
   end
   ```
   This allows `ronin new project`, `ronin new script`, etc. Each subcommand is a separate file in `commands/new/`.

5. **Core::CLI::Generator** builds on CommandKit::FileUtils - It adds `template_dir`, `print_action`, and wrappers for `mkdir`, `cp`, `erb`, `chmod`, `sh`. Gempilot's Generator follows this pattern.

6. **Consistent use of Inflector** - Ronin never hand-rolls string case conversion.

---

## Side-by-Side: CLI Entry Points

### Gempilot
```ruby
# lib/gempilot/cli.rb
class Gempilot::CLI
  include CommandKit::Commands
  include CommandKit::Commands::AutoLoad.new(
    dir:       "#{__dir__}/cli/commands",
    namespace: "#{self}::Commands"
  )
  include CommandKit::Options::Version

  command_name "gempilot"
  version Gempilot::VERSION
end
```

### Ronin
```ruby
# lib/ronin/cli.rb
class Ronin::CLI
  include CommandKit::Commands
  include CommandKit::Commands::AutoLoad.new(
    dir:       "#{__dir__}/cli/commands",
    namespace: "#{self}::Commands"
  )
  include CommandKit::Options::Version
  include Core::CLI::Help::Banner

  command_name 'ronin'
  version Ronin::VERSION

  command_aliases['enc'] = 'encode'
  command_aliases['dec'] = 'decode'
end
```

**Verdict:** Nearly identical. Gempilot follows the pattern correctly. Ronin adds `command_aliases` and a help banner, both nice touches.

---

## Side-by-Side: Generator Commands

### Gempilot - `Commands::New`
```ruby
class New < Command
  include Generator

  template_dir File.join(Gempilot::ROOT, "data", "templates", "gem")

  option :summary, value: { type: String }, desc: "Gem summary"
  option :test, value: { type: { "minitest" => :minitest, "rspec" => :rspec }, default: :minitest }, desc: "Test framework"
  argument :gem_name, required: true, desc: "Name of the gem"

  def run(gem_name)
    @gem_name = gem_name
    @module_name = inflect_module(gem_name)
    mkdir gem_name
    erb "gemspec.erb", "#{gem_name}/#{gem_name}.gemspec"
    # ...
  end
end
```

### Ronin - `Commands::New::Project`
```ruby
class Project < Command
  include Core::CLI::Generator

  template_dir File.join(ROOT, 'data', 'templates', 'project')

  option :git, desc: 'Initializes a git repo'
  option :ruby_version, value: { type: String, usage: 'VERSION', default: RUBY_VERSION }, desc: '...'
  argument :path, required: true, desc: 'The directory to create'

  description 'Creates a new Ruby project directory'
  man_page 'ronin-new-project.1'

  def run(path)
    @project_name = File.basename(path)
    @ruby_version = options[:ruby_version]
    mkdir path
    erb 'Gemfile.erb', File.join(path, 'Gemfile')
    # ...
  end
end
```

**Verdict:** Same pattern. Gempilot's version is correct. Ronin adds `man_page` declaration and uses `usage:` on option values for better help output.

---

## Grading: Gempilot's Idiomatic Use of CommandKit

### Grade: **B+**

Gempilot's restructured codebase follows the command_kit patterns well. The CLI entry, base command, AutoLoad, option/argument definitions, and Generator module all match the Ronin reference closely.

### What Earns the Grade

**Done right:**
- CLI with `Commands` + `AutoLoad` - textbook implementation
- Base `Command` class with `Colors` - follows the pattern
- Generator module following ronin-core's design
- Option definitions with `value:` Hash, proper types
- Argument definitions with `required: true`
- `template_dir` class method pattern
- `description` and `usage` on commands
- ERB templates with instance variable binding
- Executable entry point: thin `CLI.start`

**Holding it back from A:**

1. **`CommandKit::Inflector` not used** - Hand-rolled `inflect_module` instead of `Inflector.camelize`. This is specifically called out in CLAUDE.md issue #2.

2. **No `CommandKit::Interactive`** - CLAUDE.md issue #1 asks for interactive prompting when arguments are missing. `CommandKit::Interactive` provides `ask`, `ask_yes_or_no`, `ask_multiple_choice` - exactly what's needed.

3. **No `examples` on any command** - Ronin defines examples on every command. Gempilot defines none. Easy win for help output.

4. **No `bug_report_url`** - Low effort, high value for user experience.

5. **Two shell execution paths** - `Generator#sh` (uses `system`) and `Commands#sh` / `Runner` (uses Open3 pipeline with PTY). Should converge.

6. **`CommandMapper` integration unclear** - `CommandMappers::Bundle` is a 1091-line DSL that's not wired into any command yet. The `Commands::New#run` calls `sh 'bundle', 'install'` directly instead of using the typed DSL.

### What Would Make It an A

1. Replace `inflect_module` with `CommandKit::Inflector.camelize`
2. Include `CommandKit::Interactive` in base Command, use it for missing-argument prompting
3. Add `examples` to `Commands::New`
4. Add `bug_report_url` to base Command
5. Wire `CommandMappers::Bundle` into the `new` command for `bundle install` / `bundle config` operations
6. Add `CommandKit::Printing::Indent` for structured output during generation
