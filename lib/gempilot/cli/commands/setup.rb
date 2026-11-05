module Gempilot
  class CLI
    module Commands
      ## Sets up an optional tooling integration inside an existing gem.
      ##
      ## Currently supports betterleaks secret scanning:
      ## <tt>gempilot setup betterleaks</tt> installs the pre-commit hook, CI
      ## workflow, and rake task wiring. Idempotent, safe to re-run.
      class Setup < Command
        include Generator
        include GemContext

        template_dir File.join(Gempilot::ROOT, "data", "templates", "gem")

        usage "[options] FEATURE"
        description "Set up a tooling integration in an existing gem"

        examples [
          "betterleaks",
        ]

        FEATURES = %w[betterleaks].freeze

        argument :feature, required: false,
                           desc: "Integration to set up (betterleaks)"

        def run(feature = nil)
          feature ||= prompt_for_feature
          detect_gem_context
          dispatch_setup(feature)
        end

        private

        def prompt_for_feature
          puts colors.bright_black("Which integration do you want to set up?")
          ask_multiple_choice(colors.green("Feature"), FEATURES)
        end

        def dispatch_setup(feature)
          case feature
          when "betterleaks" then setup_betterleaks
          else
            puts colors.red("Unknown feature '#{feature}'. Available: #{FEATURES.join(", ")}.")
            exit 1
          end
        end

        def setup_betterleaks
          print_setup_banner("betterleaks")
          Betterleaks.new(self).install
          sh "git", "config", "core.hooksPath", Betterleaks::HOOKS_PATH
        end

        def print_setup_banner(feature)
          puts
          puts colors.bright_white("Setting up ") + colors.bold(colors.cyan(feature)) + colors.bright_white("...")
          puts
        end
      end
    end
  end
end
