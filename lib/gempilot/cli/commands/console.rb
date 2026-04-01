require_relative "../command"
require_relative "../gem_context"
require "bundler"

module Gempilot
  class CLI
    module Commands
      ## Launches an IRB session via the gem's +bin/console+ script.
      class Console < Command
        include GemContext

        description "Start an interactive console with the gem loaded (delegates to bin/console)"

        def run
          detect_gem_context
          console_path = find_console_script
          print_console_banner
          Bundler.with_unbundled_env { exec(console_path) }
        end

        private

        def find_console_script
          path = File.join(Dir.pwd, "bin", "console")
          return path if File.exist?(path)

          puts colors.red("bin/console not found. Run this from your gem's root directory.")
          exit 1
        end

        def print_console_banner
          puts colors.bright_white("Starting console for ") +
               colors.bold(colors.cyan(@gem_name)) +
               colors.bright_white("...")
          puts
        end
      end
    end
  end
end
