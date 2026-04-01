require_relative "../command"
require_relative "../gem_context"
require "bundler"

module Gempilot
  class CLI
    module Commands
      ## Delegates to +rake release+ to build and push the gem.
      class Release < Command
        include GemContext

        description "Release the gem (delegates to rake release)"

        def run
          detect_gem_context

          puts colors.bright_white("Releasing ") + colors.bold(colors.cyan(@gem_name)) + colors.bright_white("...")
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
