# CommandKit 0.6.0 - Complete Module & Method Reference

## Overview

CommandKit is a modular Ruby toolkit for building CLI commands. Rather than a monolithic framework, it provides composable modules that can be included individually or used together via the `CommandKit::Command` base class.

**Key design principle:** Every module follows the `include`-based mixin pattern with `ClassMethods` for DSL methods and instance methods for runtime behavior. Modules are testable by injecting `stdin:`, `stdout:`, `stderr:`, and `env:` into `initialize`.

---

## Core Command Class

### `CommandKit::Command`
**Path:** `lib/command_kit/command.rb`

Base class that combines all standard modules. Inheriting from this is optional - you can include individual modules instead.

**Includes (in order):** Main, Env, Stdio, Printing, Help, Usage, Arguments, Options, Examples, Description, ExceptionHandler, FileUtils

---

## Lifecycle Modules

### `CommandKit::Main`
**Path:** `lib/command_kit/main.rb`

Entry point and command lifecycle management.

| Method | Type | Signature | Purpose |
|--------|------|-----------|---------|
| `start` | Class | `start(argv=ARGV, **kwargs)` | Creates instance, calls `main`, exits with status. Catches `Interrupt` (exit 130) and `Errno::EPIPE` (exit 0) |
| `main` | Class | `main(argv=[], **kwargs) -> Integer` | Creates instance, calls instance `#main`, returns exit code |
| `main` | Instance | `main(argv=[]) -> Integer` | Calls `run(*argv)`, catches `SystemExit`, returns 0 by default |
| `run` | Instance | `run(*args)` | Abstract. Override with command logic |

---

### `CommandKit::Env`
**Path:** `lib/command_kit/env.rb`

Testable access to environment variables.

| Method | Type | Signature | Purpose |
|--------|------|-----------|---------|
| `env` | Instance | `-> Hash` | Returns `@env` (defaults to `ENV`) |

Initialize with `env: { 'KEY' => 'val' }` for testing.

---

### `CommandKit::Stdio`
**Path:** `lib/command_kit/stdio.rb`

Testable stream access. Initialize with `stdin:`, `stdout:`, `stderr:` for testing.

| Method | Type | Signature | Purpose |
|--------|------|-----------|---------|
| `stdin` | Instance | `-> IO` | Returns `@stdin` or `$stdin` |
| `stdout` | Instance | `-> IO` | Returns `@stdout` or `$stdout` |
| `stderr` | Instance | `-> IO` | Returns `@stderr` or `$stderr` |
| `gets` | Instance | `gets(*args)` | Delegates to `stdin.gets` |
| `readline` | Instance | `readline(*args)` | Delegates to `stdin.readline` |
| `readlines` | Instance | `readlines(*args)` | Delegates to `stdin.readlines` |
| `putc` | Instance | `putc(*args)` | Delegates to `stdout.putc` |
| `puts` | Instance | `puts(*args)` | Delegates to `stdout.puts` |
| `print` | Instance | `print(*args)` | Delegates to `stdout.print` |
| `printf` | Instance | `printf(*args)` | Delegates to `stdout.printf` |
| `abort` | Instance | `abort(message=nil)` | Prints to stderr, exits(1) |

---

## CLI Definition Modules

### `CommandKit::CommandName`
**Path:** `lib/command_kit/command_name.rb`

Derives command name from class name or sets it explicitly.

| Method | Type | Signature | Purpose |
|--------|------|-----------|---------|
| `command_name` | Class | `command_name(name=nil) -> String` | Gets/sets. Defaults to `Inflector.underscore(Inflector.demodularize(self.name))` |
| `command_name` | Instance | `-> String` | Reader |

---

### `CommandKit::Usage`
**Path:** `lib/command_kit/usage.rb`
**Includes:** CommandName, Help

| Method | Type | Signature | Purpose |
|--------|------|-----------|---------|
| `usage` | Class | `usage(str=nil) -> String\|Array` | Gets/sets usage string(s). Example: `usage '[options] FILE'` |
| `usage` | Instance | `-> String\|Array` | Prepends `command_name` to class usage |
| `help_usage` | Instance | `-> nil` | Prints formatted `usage: ...` |

---

### `CommandKit::Description`
**Path:** `lib/command_kit/description.rb`
**Includes:** Help

| Method | Type | Signature | Purpose |
|--------|------|-----------|---------|
| `description` | Class | `description(str=nil) -> String\|nil` | Gets/sets description |
| `description` | Instance | `-> String\|nil` | Reader |
| `help_description` | Instance | `-> nil` | Prints description section |

---

### `CommandKit::Examples`
**Path:** `lib/command_kit/examples.rb`
**Includes:** Help, CommandName

| Method | Type | Signature | Purpose |
|--------|------|-----------|---------|
| `examples` | Class | `examples(arr=nil) -> Array\|nil` | Gets/sets example strings |
| `examples` | Instance | `-> Array\|nil` | Reader, prepends `command_name` |
| `help_examples` | Instance | `-> nil` | Prints examples section |

---

### `CommandKit::Arguments`
**Path:** `lib/command_kit/arguments.rb`
**Includes:** Usage, Main, Help, Printing

| Method | Type | Signature | Purpose |
|--------|------|-----------|---------|
| `arguments` | Class | `-> Hash{Symbol => Argument}` | All defined arguments (inherits) |
| `argument` | Class | `argument(name, required: true, repeats: false, desc:, usage: nil)` | Define a positional argument |
| `main` | Instance | `main(argv=[]) -> Integer` | Validates argument count, then calls super |
| `help_arguments` | Instance | `-> nil` | Prints arguments section |

**Argument options:**
- `required:` (Boolean, default: true)
- `repeats:` (Boolean, default: false) - allows multiple values
- `desc:` (String or Array<String>) - description
- `usage:` (String) - override display name (defaults to uppercase `name`)

---

### `CommandKit::Options`
**Path:** `lib/command_kit/options.rb`
**Includes:** Arguments, Options::Parser

| Method | Type | Signature | Purpose |
|--------|------|-----------|---------|
| `options` | Class | `-> Hash{Symbol => Option}` | All defined options (inherits) |
| `option` | Class | `option(name, short:, long:, equals:, value:, desc:, category:, &block)` | Define an option |
| `options` | Instance | `-> Hash{Symbol => Object}` | Parsed option values |

**Option parameters:**
- `short:` (String, e.g. `'-f'`)
- `long:` (String, defaults to `"--#{dasherize(name)}"`)
- `equals:` (Boolean) - use `--opt=VALUE` form
- `value:` (Hash or true/false/nil):
  - `type:` (Class, Hash, Array, Regexp) - `String`, `Integer`, `Float`, `Numeric`, `Date`, `Time`, `URI`, `Regexp`, `Hash{'a'=>:a}`, `Array[:a,:b]`
  - `usage:` (String) - value placeholder
  - `default:` (Object or Proc)
  - `required:` (Boolean)
- `desc:` (String or Array<String>)
- `category:` (String) - groups options in help
- `&block` - receives parsed value for custom processing

---

### `CommandKit::Options::Parser`
**Path:** `lib/command_kit/options/parser.rb`
**Includes:** Usage, Main, Printing

| Method | Type | Signature | Purpose |
|--------|------|-----------|---------|
| `option_parser` | Instance | `-> OptionParser` | The underlying OptionParser |
| `main` | Instance | `main(argv=[]) -> Integer` | Parses options then calls super |
| `parse_options` | Instance | `parse_options(argv) -> Array` | Parses, returns remaining args |
| `on_parse_error` | Instance | `on_parse_error(error)` | Prints error + "Try --help", exits(1) |
| `on_invalid_option` | Instance | `on_invalid_option(error)` | Override for OptionParser::InvalidOption |
| `on_ambiguous_option` | Instance | `on_ambiguous_option(error)` | Override for OptionParser::AmbiguousOption |
| `on_invalid_argument` | Instance | `on_invalid_argument(error)` | Override for OptionParser::InvalidArgument |
| `on_missing_argument` | Instance | `on_missing_argument(error)` | Override for OptionParser::MissingArgument |
| `on_needless_argument` | Instance | `on_needless_argument(error)` | Override for OptionParser::NeedlessArgument |

---

### Pre-built Option Modules

#### `CommandKit::Options::Verbose`
Adds `-v, --verbose` flag. Provides `verbose?` -> Boolean.

#### `CommandKit::Options::VerboseLevel`
Adds `-v, --verbose` that increments on each use. Provides `verbose` -> Integer, `verbose?` -> Boolean.

#### `CommandKit::Options::Quiet`
Adds `-q, --quiet` flag. Provides `quiet?` -> Boolean.

#### `CommandKit::Options::Version`
Adds `-V, --version` flag. Class method `version(str)` sets version. `print_version` prints `"#{command_name} #{version}"`.

---

## Subcommand System

### `CommandKit::Commands`
**Path:** `lib/command_kit/commands.rb`
**Includes:** CommandName, Usage, Options, Stdio, Env

When included, automatically sets usage to `"[options] [COMMAND [ARGS...]]"` and mounts a `Help` subcommand.

| Method | Type | Signature | Purpose |
|--------|------|-----------|---------|
| `commands` | Class | `-> Hash{String => Subcommand}` | Registered subcommands (inherits) |
| `command_aliases` | Class | `-> Hash{String => String}` | Alias mappings (inherits) |
| `command` | Class | `command(name=nil, klass, summary:, aliases:)` | Register a subcommand |
| `get_command` | Class | `get_command(name) -> Class\|nil` | Look up by name or alias |
| `command` | Instance | `command(name) -> Object\|nil` | Instantiate subcommand with inherited context |
| `invoke` | Instance | `invoke(name, *argv) -> Integer` | Invoke subcommand, return exit status |
| `run` | Instance | `run(cmd=nil, *argv)` | Dispatch to subcommand or show help |
| `command_not_found` | Instance | `command_not_found(name)` | Print error, exit(1) |
| `on_unknown_command` | Instance | `on_unknown_command(name, argv)` | Override for custom handling |
| `help_commands` | Instance | `-> nil` | Print commands list |

---

### `CommandKit::Commands::AutoLoad`
**Path:** `lib/command_kit/commands/auto_load.rb`

Auto-discovers subcommands from a directory. Used like:
```ruby
include CommandKit::Commands::AutoLoad.new(
  dir:       "#{__dir__}/commands",
  namespace: "#{self}::Commands"
)
```

| Method | Type | Signature | Purpose |
|--------|------|-----------|---------|
| `new` | Class | `new(dir:, namespace:)` | Creates an auto-loading module |
| `join` | Instance | `join(path)` | Joins dir + path |
| `files` | Instance | `-> Hash{String => String}` | Maps command names to file paths |
| `commands` | Instance | `-> Hash{String => Subcommand}` | Lazily loads commands from files |

Files are discovered as `dir/*.rb` and command names derived via `Inflector.demodularize`.

---

### `CommandKit::Commands::AutoRequire`
**Path:** `lib/command_kit/commands/auto_require.rb`

Similar to AutoLoad but uses `require` with a namespace prefix instead of file paths.

---

### `CommandKit::Commands::ParentCommand`
**Path:** `lib/command_kit/commands/parent_command.rb`

| Method | Type | Signature | Purpose |
|--------|------|-----------|---------|
| `parent_command` | Instance | `-> Object` | Reader for the parent command |

---

## Interactive Input

### `CommandKit::Interactive`
**Path:** `lib/command_kit/interactive.rb`
**Includes:** Stdio

| Method | Type | Signature | Purpose |
|--------|------|-----------|---------|
| `ask` | Instance | `ask(prompt, default: nil, required: false) -> String` | Prompt for text input |
| `ask_yes_or_no` | Instance | `ask_yes_or_no(prompt, default: nil) -> Boolean` | Y/N prompt |
| `ask_multiple_choice` | Instance | `ask_multiple_choice(prompt, choices) -> String` | Numbered selection. `choices` is Array or Hash |
| `ask_secret` | Instance | `ask_secret(prompt, required: true) -> String` | Input with echo disabled |
| `ask_multiline` | Instance | `ask_multiline(prompt, terminator: :ctrl_d) -> String` | Multi-line input. Terminator: `:ctrl_d` or `:double_newline` |

---

## Output Modules

### `CommandKit::Printing`
**Path:** `lib/command_kit/printing.rb`
**Includes:** Stdio

| Method | Type | Signature | Purpose |
|--------|------|-----------|---------|
| `print_error` | Instance | `print_error(message)` | Print to stderr, prefix with command_name |
| `print_exception` | Instance | `print_exception(error)` | Print exception to stderr with formatting |

**Constant:** `EOL = $/` (platform-independent newline)

---

### `CommandKit::Printing::Indent`
**Path:** `lib/command_kit/printing/indent.rb`

| Method | Type | Signature | Purpose |
|--------|------|-----------|---------|
| `indent` | Instance | `indent(n=2) { ... }` | Increase indent for block, then restore |
| `puts` | Instance | `puts(*lines)` | Override: prepends indent padding |

---

### `CommandKit::Printing::Fields`
**Path:** `lib/command_kit/printing/fields.rb`
**Includes:** Indent

| Method | Type | Signature | Purpose |
|--------|------|-----------|---------|
| `print_fields` | Instance | `print_fields(fields)` | Print aligned key: value pairs |

---

### `CommandKit::Printing::Lists`
**Path:** `lib/command_kit/printing/lists.rb`
**Includes:** Indent

| Method | Type | Signature | Purpose |
|--------|------|-----------|---------|
| `print_list` | Instance | `print_list(list, bullet: '*')` | Print bulleted list with nesting support |

---

### `CommandKit::Printing::Tables`
**Path:** `lib/command_kit/printing/tables.rb`
**Includes:** Indent

| Method | Type | Signature | Purpose |
|--------|------|-----------|---------|
| `print_table` | Instance | `print_table(rows, header:, border:, padding:, justify:, justify_header:, separate_rows:)` | Print formatted table |

**Border styles:** `:ascii` (+-|), `:line` (Unicode box), `:double_line` (Unicode double), `nil` (no borders), or custom Hash.

---

### `CommandKit::Colors`
**Path:** `lib/command_kit/colors.rb`
**Includes:** Stdio, Env

| Method | Type | Signature | Purpose |
|--------|------|-----------|---------|
| `ansi?` | Instance | `ansi?(stream=stdout) -> Boolean` | Check if stream supports ANSI (respects `NO_COLOR`, `TERM=dumb`) |
| `colors` | Instance | `colors(stream=stdout) -> ANSI\|PlainText` | Returns color module |

**Color methods** (on the returned `colors` object):
`reset`, `bold`, `black`, `red`, `green`, `yellow`, `blue`, `magenta`, `cyan`, `white`, `bright_black`/`gray`, `bright_red`, `bright_green`, `bright_yellow`, `bright_blue`, `bright_magenta`, `bright_cyan`, `bright_white`

All have corresponding `on_*` background variants. Each accepts optional string: `colors.red("error")` or returns code: `colors.red`.

---

## Utilities

### `CommandKit::Inflector`
**Path:** `lib/command_kit/inflector.rb`

All module-level methods (no include needed):

| Method | Signature | Purpose |
|--------|-----------|---------|
| `demodularize` | `demodularize(name) -> String` | `"Foo::Bar::Baz"` -> `"Baz"` |
| `underscore` | `underscore(name) -> String` | `"MyCommandName"` -> `"my_command_name"` |
| `dasherize` | `dasherize(name) -> String` | `"my_command_name"` -> `"my-command-name"` |
| `camelize` | `camelize(name) -> String` | `"my_command_name"` -> `"MyCommandName"`, `"my/cmd"` -> `"My::Cmd"` |

---

### `CommandKit::FileUtils`
**Path:** `lib/command_kit/file_utils.rb`
**Includes:** `::FileUtils` (Ruby stdlib)

| Method | Type | Signature | Purpose |
|--------|------|-----------|---------|
| `erb` | Instance | `erb(source, dest=nil) -> String\|nil` | Render ERB template. If `dest`, writes file. Otherwise returns string. Uses `trim_mode: '-'` |

All standard Ruby `FileUtils` methods are also available (`mkdir_p`, `cp`, `rm`, `chmod`, etc.).

---

### `CommandKit::Edit`
**Path:** `lib/command_kit/edit.rb`
**Includes:** Env

| Method | Type | Signature | Purpose |
|--------|------|-----------|---------|
| `editor` | Instance | `-> String` | Returns `$EDITOR` or `"nano"` |
| `edit` | Instance | `edit(*arguments) -> Boolean\|nil` | Opens editor via `system` |

---

### `CommandKit::Pager`
**Path:** `lib/command_kit/pager.rb`
**Includes:** Env, Env::Path, Stdio, Terminal

| Method | Type | Signature | Purpose |
|--------|------|-----------|---------|
| `pager` | Instance | `pager { \|io\| ... }` | Pipe output through pager (less/more) |
| `print_or_page` | Instance | `print_or_page(data)` | Auto-page if data exceeds terminal height |
| `pipe_to_pager` | Instance | `pipe_to_pager(cmd, *args)` | Pipe command output through pager |

---

### `CommandKit::Terminal`
**Path:** `lib/command_kit/terminal.rb`
**Includes:** Stdio, Env

| Method | Type | Signature | Purpose |
|--------|------|-----------|---------|
| `terminal?` / `tty?` | Instance | `-> Boolean` | Check if stdout is a TTY |
| `terminal` | Instance | `-> IO\|nil` | Returns `IO.console` or nil |
| `terminal_height` | Instance | `-> Integer` | Terminal rows (default 25) |
| `terminal_width` | Instance | `-> Integer` | Terminal columns (default 80) |
| `terminal_size` | Instance | `-> [Integer, Integer]` | `[height, width]` |

---

### `CommandKit::OS`
**Path:** `lib/command_kit/os.rb`

| Method | Type | Signature | Purpose |
|--------|------|-----------|---------|
| `os` | Class | `-> Symbol\|nil` | Detects OS: `:linux`, `:macos`, `:freebsd`, `:openbsd`, `:netbsd`, `:windows` |
| `os` | Instance | `-> Symbol\|nil` | Reader |
| `linux?` | Instance | `-> Boolean` | |
| `macos?` | Instance | `-> Boolean` | |
| `bsd?` | Instance | `-> Boolean` | Any BSD variant |
| `unix?` | Instance | `-> Boolean` | Linux, macOS, or BSD |
| `windows?` | Instance | `-> Boolean` | |

---

### `CommandKit::PackageManager`
**Path:** `lib/command_kit/package_manager.rb`
**Includes:** OS, OS::Linux, Env::Path, Sudo

| Method | Type | Signature | Purpose |
|--------|------|-----------|---------|
| `package_manager` | Instance | `-> Symbol\|nil` | Detected manager: `:apt`, `:dnf`, `:yum`, `:zypper`, `:pacman`, `:brew`, `:port`, `:pkg`, `:pkg_add` |
| `install_packages` | Instance | `install_packages(*packages, yes:, apt:, brew:, dnf:, ...)` | Install packages cross-platform |

---

### `CommandKit::Sudo`
**Path:** `lib/command_kit/sudo.rb`
**Includes:** OS

| Method | Type | Signature | Purpose |
|--------|------|-----------|---------|
| `sudo` | Instance | `sudo(command, *args) -> Boolean\|nil` | Run command with sudo/runas if not root |

---

### `CommandKit::Open`
**Path:** `lib/command_kit/open.rb`
**Includes:** Stdio, Printing

| Method | Type | Signature | Purpose |
|--------|------|-----------|---------|
| `open` | Instance | `open(path, mode='r', &block)` | Open file with error handling. `"-"` maps to stdin/stdout |

---

### `CommandKit::OpenApp`
**Path:** `lib/command_kit/open_app.rb`
**Includes:** OS, Env::Path

| Method | Type | Signature | Purpose |
|--------|------|-----------|---------|
| `open_app_for` | Instance | `open_app_for(file_or_uri)` | Open with system app (`open`/`xdg-open`/`start`) |

---

### `CommandKit::BugReport`
**Path:** `lib/command_kit/bug_report.rb`
**Includes:** ExceptionHandler, Printing

| Method | Type | Signature | Purpose |
|--------|------|-----------|---------|
| `bug_report_url` | Class | `bug_report_url(url=nil) -> String\|nil` | Gets/sets bug report URL |
| `on_exception` | Instance | `on_exception(error)` | Prints bug report with URL, exits(-1) |

---

### `CommandKit::XDG`
**Path:** `lib/command_kit/xdg.rb`
**Includes:** CommandName, Env::Home

| Method | Type | Signature | Purpose |
|--------|------|-----------|---------|
| `xdg_namespace` | Class | `xdg_namespace(ns=nil) -> String` | Gets/sets XDG subdirectory name |
| `config_dir` | Instance | `-> String` | `~/.config/<namespace>` |
| `local_share_dir` | Instance | `-> String` | `~/.local/share/<namespace>` |
| `cache_dir` | Instance | `-> String` | `~/.cache/<namespace>` |

Respects `$XDG_CONFIG_HOME`, `$XDG_DATA_HOME`, `$XDG_CACHE_HOME`.

---

### `CommandKit::Help::Man`
**Path:** `lib/command_kit/help/man.rb`
**Includes:** CommandName, Help, Stdio, CommandKit::Man

| Method | Type | Signature | Purpose |
|--------|------|-----------|---------|
| `man_dir` | Class | `man_dir(path=nil) -> String` | Gets/sets man page directory |
| `man_page` | Class | `man_page(page=nil) -> String` | Gets/sets man page file (defaults to `"#{command_name}.1"`) |
| `help_man` | Instance | `help_man(page)` | Display man page |
| `help` | Instance | `-> nil` | Shows man page if TTY, else falls back to text help |

---

### `CommandKit::ProgramName`
**Path:** `lib/command_kit/program_name.rb`

| Method | Type | Signature | Purpose |
|--------|------|-----------|---------|
| `program_name` | Class | `-> String\|nil` | Returns `$PROGRAM_NAME` (ignores `-e`, `irb`, `rspec`) |
| `program_name` | Instance | `-> String\|nil` | Delegates to class |
| `command_name` | Instance | `-> String\|nil` | Alias for `program_name` |
