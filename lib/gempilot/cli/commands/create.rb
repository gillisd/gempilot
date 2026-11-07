module Gempilot
  class CLI
    module Commands
      ## Creates a new gem: writes its files, runs its +bin/setup+, and commits it.
      ##
      ##   $ gempilot create --test minitest --git my_gem
      ##   # Creating gem 'my_gem'...
      ##   # ...
      ##   # run  bin/setup
      ##   # run  git init -q -b master
      class Create < GemScaffold
        usage "[options] GEM_NAME"
        description "Create a new gem"

        examples [
          "my_gem",
          "--test rspec my_gem",
          "--exe --git my_gem",
          "--git --branch main my_gem",
          "--summary 'A web scraper' my_gem",
        ]

        def run(gem_name = nil)
          super
          begin
            run_setup
            initialize_git_repo
          rescue Shell::CommandFailed => e
            puts colors.red(e.message)
            exit 1
          end
        end

        private

        def run_setup
          cd @gem_name do
            run_command "bin/setup"
          end
        end

        def initialize_git_repo
          return unless options[:git]

          cd @gem_name do
            run_command "git", "init", "-q", "-b", @branch
            run_command "git", "add", "."
            run_command "git", "commit", "-q", "-m", commit_message
          end
        end

        # "Initial commit." is wrong when scaffolding into a directory that is
        # already a repository with history (e.g. a cloned remote), so name the
        # commit after the gem in that case.
        def commit_message
          existing_history? ? "Add #{@gem_name} gem scaffolding." : "Initial commit."
        end

        def existing_history?
          Shell.capture("git", "rev-parse", "--verify", "--quiet", "HEAD").success?
        end
      end
    end
  end
end
