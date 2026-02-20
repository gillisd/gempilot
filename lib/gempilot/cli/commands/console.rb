require_relative "../command"
require_relative "../gem_context"
require "bundler"

module Gempilot
  class CLI
    module Commands
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

          label = colors.bold(colors.cyan(@gem_name))
          prefix = colors.bright_white("Starting console for ")
          puts "#{prefix}#{label}#{colors.bright_white('...')}"
          puts

          Bundler.with_unbundled_env do
            exec(console_path)
          end
        end
      end
    end
  end
end
