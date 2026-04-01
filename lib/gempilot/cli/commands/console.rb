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

          console_path = File.join(Dir.pwd, "bin", "console")

          unless File.exist?(console_path)
            puts colors.red("bin/console not found. Run this from your gem's root directory.")
            exit 1
          end

          puts colors.bright_white("Starting console for ") + colors.bold(colors.cyan(@gem_name)) + colors.bright_white("...")
          puts

          Bundler.with_unbundled_env do
            exec(console_path)
          end
        end
      end
    end
  end
end
