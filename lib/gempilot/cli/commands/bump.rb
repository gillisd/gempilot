require "bundler"

module Gempilot
  class CLI
    module Commands
      ## Delegates version bumping to +rake version:bump[segment]+.
      class Bump < Command
        include GemContext

        usage "[options] [SEGMENT]"
        description "Bump the gem version (patch by default, or minor/major/tiny/dev)"

        examples [
          "",
          "patch",
          "minor",
          "major",
          "tiny",
          "dev",
        ]

        argument :segment, required: false,
                           desc: "Version segment to bump: patch (default), minor, major, tiny, or dev"

        def run(segment = "patch")
          detect_gem_context
          segment = validate_segment(segment)
          run_rake_bump(segment)
        end

        private

        def validate_segment(segment)
          segment = segment.downcase
          return segment if %w[patch minor major tiny dev].include?(segment)

          puts colors.red("Unknown segment '#{segment}'. Use patch, minor, major, tiny, or dev.")
          exit 1
        end

        def run_rake_bump(segment)
          success = Bundler.with_unbundled_env do
            system("bundle", "exec", "rake", "version:bump[#{segment}]")
          end
          exit 1 unless success
        end
      end
    end
  end
end
