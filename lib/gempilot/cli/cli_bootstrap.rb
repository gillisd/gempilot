module Gempilot
  class CLI
    ##
    # Scaffolds the CommandKit plumbing a generated command needs and the gem
    # is missing: the +CLI+ router, the base +Command+ class, an executable
    # that starts the router, the Zeitwerk inflection letting +cli.rb+ define
    # +CLI+ rather than +Cli+, and the +command_kit+ runtime dependency.
    #
    # Every step is idempotent, so a gem that already has any of these pieces
    # keeps them untouched. Expects the including command to provide the
    # Generator methods and +@gem_name+, +@require_path+, and +@gem_module+.
    module CliBootstrap
      TEMPLATES = Gempilot::ROOT.join("data", "templates", "cli").to_s.freeze
      CLI_INFLECTION = 'l.inflector.inflect("cli" => "CLI")'.freeze
      TAP_SETUP = ".tap(&:setup)".freeze

      private

      # Returns the gemspec path when it gained the command_kit dependency
      # (so the caller knows a bundle install is due), nil otherwise.
      def bootstrap_cli
        create_cli_router
        create_base_command
        create_executable
        inflect_cli_constant
        add_command_kit_dependency
      end

      def create_cli_router
        render_once "cli.rb.erb", File.join("lib", @require_path, "cli.rb")
      end

      def create_base_command
        render_once "command.rb.erb", File.join("lib", @require_path, "cli", "command.rb")
      end

      def render_once(template, path)
        return if File.exist?(path)

        ensure_directory(File.dirname(path))
        erb template, path, from: TEMPLATES
      end

      def create_executable
        path = File.join("exe", @gem_name)
        render_once "exe.erb", path
        chmod "+x", path unless File.executable?(path)
        return if File.read(path).include?("CLI.start")

        puts colors.yellow("#{path} does not start #{@gem_module}::CLI; add `#{@gem_module}::CLI.start` to it.")
      end

      def inflect_cli_constant
        path = File.join("lib", "#{@require_path}.rb")
        source = File.exist?(path) ? File.read(path) : ""
        return if source.include?(CLI_INFLECTION)

        line = source.lines.find { it.include?(TAP_SETUP) }
        return hint_inflection(path) unless line

        update_file path, source.sub(TAP_SETUP, inflection_block(indent_of(line)))
      end

      def inflection_block(indent)
        [".tap do |l|", "#{indent}  #{CLI_INFLECTION}", "#{indent}  l.setup", "#{indent}end"].join("\n")
      end

      def indent_of(line)
        line[0, line.length - line.lstrip.length]
      end

      def hint_inflection(path)
        puts colors.yellow("Could not find #{TAP_SETUP} in #{path}; add #{CLI_INFLECTION} before the loader's setup.")
      end

      def add_command_kit_dependency
        path = "#{@gem_name}.gemspec"
        lines = File.readlines(path)
        return if lines.any? { it.include?("command_kit") }

        index = lines.index { it.include?(".add_dependency") } || lines.rindex { it.strip == "end" }
        index ? insert_dependency(path, lines, index) : hint_dependency(path)
      end

      def insert_dependency(path, lines, index)
        lines.insert(index, %(  #{gemspec_receiver(lines)}.add_dependency "command_kit"\n))
        update_file path, lines.join
        path
      end

      def gemspec_receiver(lines)
        line = lines.find { it.include?(".add_dependency") }
        line ? line.strip[0, line.strip.index(".add_dependency")] : "spec"
      end

      def hint_dependency(path)
        puts colors.yellow("Could not add command_kit to #{path}; add `spec.add_dependency \"command_kit\"` yourself.")
      end
    end
  end
end
