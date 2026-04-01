require_relative "../command"
require_relative "../generator"
require_relative "../gem_builder"
require "command_kit/inflector"

module Gempilot
  class CLI
    module Commands
      ## Scaffolds a new gem with Zeitwerk autoloading, test framework, RuboCop config,
      ## CI workflow, and version management rake tasks.
      class Create < Command
        include Generator
        include GemBuilder

        template_dir File.join(Gempilot::ROOT, "data", "templates", "gem")

        usage "[options] GEM_NAME"
        description "Create a new gem"

        examples [
          "my_gem",
          "--test rspec my_gem",
          "--exe --git my_gem",
          "--git --branch main my_gem",
          "--summary 'A web scraper' my_gem",
        ]

        option :summary, value: { type: String },
                         desc: "Gem summary"

        option :author, value: {
                          type: String,
                          default: -> { `git config user.name 2>/dev/null`.strip },
                        },
                        desc: "Author name"

        option :email, value: {
                         type: String,
                         default: -> { `git config user.email 2>/dev/null`.strip },
                       },
                       desc: "Author email"

        option :ruby_version, value: {
                                type: String,
                                default: RUBY_VERSION,
                              },
                              desc: "Minimum Ruby version"

        option :test, value: {
                        type: { "minitest" => :minitest, "rspec" => :rspec },
                      },
                      desc: "Test framework"

        option :exe, long: "--[no-]exe", desc: "Create an executable"

        option :git, long: "--[no-]git", desc: "Initialize git repo"

        option :branch, value: { type: String },
                        desc: "Git branch name"

        argument :gem_name, required: false,
                            desc: "Name of the gem"

        def run(gem_name = nil)
          puts colors.bold("Creating gem...")
          puts
          collect_options(gem_name)
          print_header
          scaffold_gem
        end

        private

        def collect_options(gem_name)
          collect_gem_name(gem_name)
          derive_naming
          collect_author_info
          collect_summary
          collect_build_options
        end

        def scaffold_gem
          create_directories
          render_core_templates
          render_test_templates
          render_dev_files
          render_config_files
          render_executable
          run_bundle_install
          initialize_git_repo
        end

        def collect_gem_name(gem_name)
          @gem_name = gem_name || begin
            puts colors.bright_black("The gem name determines the directory, require path, and gemspec name.")
            ask(colors.green("Gem name"), required: true)
          end
        end

        def derive_naming
          @require_path = @gem_name.tr("-", "/")
          @module_name = CommandKit::Inflector.camelize(@require_path)
          @module_parts = @module_name.split("::")
          @base_module = @module_parts.first
          @hyphenated = @gem_name.include?("-")
        end

        def collect_author_info
          @author = option_or_ask(:author, "The author name for the gemspec and LICENSE.", "Author name")
          @email = option_or_ask(:email, "The contact email for the gemspec.", "Author email")
        end

        def option_or_ask(key, hint, label)
          options[key].then { |v| v.to_s.empty? ? nil : v } || begin
            puts colors.bright_black(hint)
            ask(colors.green(label), required: true)
          end
        end

        def collect_summary
          @summary = options[:summary] || begin
            puts
            puts colors.bright_black("A short (one line) summary of what your gem does.")
            ask(colors.green("Summary"), default: "A new Ruby gem")
          end
          @ruby_version = options[:ruby_version]
        end

        def collect_build_options
          collect_test_framework
          collect_exe_option
          collect_git_options
        end

        def collect_test_framework
          @test_framework = options[:test] || begin
            puts
            puts colors.bright_black("Choose a test framework for your gem:")
            puts "  * #{colors.bold("Minitest")} - https://github.com/minitest/minitest"
            puts "  * #{colors.bold("RSpec")}    - https://rspec.info"
            ask_multiple_choice(colors.green("Test framework"), { "minitest" => :minitest, "rspec" => :rspec })
          end
        end

        def collect_exe_option
          return if options.key?(:exe)

          puts
          puts colors.bright_black("An executable in exe/ lets users run your gem from the command line.")
          options[:exe] = ask_yes_or_no(colors.green("Create an executable"), default: false)
        end

        def collect_git_options
          collect_git_flag
          collect_branch if options[:git]
        end

        def collect_git_flag
          return if options.key?(:git)

          puts
          puts colors.bright_black("Initialize a git repository with an initial commit.")
          options[:git] = ask_yes_or_no(colors.green("Initialize git repo"), default: true)
        end

        def collect_branch
          @branch = options[:branch] || begin
            puts
            puts colors.bright_black("The default branch name for the new git repository.")
            ask(colors.green("Branch name"), default: "master")
          end
        end

        def print_header
          puts
          puts colors.bright_white("Creating gem '") + colors.bold(colors.cyan(@gem_name)) + colors.bright_white("'...")
          puts
        end

        def minor_version_for(version)
          version.split(".")[0..1].join(".")
        end
      end
    end
  end
end
