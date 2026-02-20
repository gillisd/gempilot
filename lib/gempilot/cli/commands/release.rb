require_relative "../command"
require_relative "../gem_context"
require "bundler"

module Gempilot
  class CLI
    module Commands
      class Release < Command
        include GemContext

        description "Release the gem (delegates to rake release)"

        def run
          detect_gem_context

          gem_label = colors.bold(colors.cyan(@gem_name))
          puts "#{colors.bright_white('Releasing ')}#{gem_label}#{colors.bright_white('...')}"
          puts

          success = Bundler.with_unbundled_env do
            system("bundle", "exec", "rake", "release")
          end

          return if success

          puts colors.red("Release failed. Check the output above for errors.")
          exit 1
        end
      end
    end
  end
end
