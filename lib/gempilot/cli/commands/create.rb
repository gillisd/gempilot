
require_relative "../command"
require_relative "../generator"
require "command_kit/inflector"

module Gempilot
  class CLI
    module Commands
      class Create < Command
        include Generator

        template_dir File.join(Gempilot::ROOT, "data", "templates", "gem")

        usage "[options] GEM_NAME"
        description "Create a new gem"

        examples [
          "my_gem",
          "--test rspec my_gem",
          "--exe --git my_gem",
          "--git --branch main my_gem",
          "--summary 'A web scraper' my_gem"
        ]

        option :summary, value: { type: String },
                         desc: "Gem summary"

        option :author, value: {
                          type: String,
                          default: -> { `git config user.name`.strip }
                        },
                        desc: "Author name"

        option :email, value: {
                         type: String,
                         default: -> { `git config user.email`.strip }
                       },
                       desc: "Author email"

        option :ruby_version, value: {
                                type: String,
                                default: RUBY_VERSION
                              },
                              desc: "Minimum Ruby version"

        option :test, value: {
                        type: { "minitest" => :minitest, "rspec" => :rspec }
                      },
                      desc: "Test framework"

        option :exe, long: '--[no-]exe', desc: "Create an executable"

        option :git, long: '--[no-]git', desc: "Initialize git repo"

        option :branch, value: { type: String },
                        desc: "Git branch name"

        argument :gem_name, required: false,
                            desc: "Name of the gem"

        def run(gem_name = nil)
          puts colors.bold("Creating gem...")
          puts

          @gem_name = gem_name || begin
            puts colors.bright_black("The gem name determines the directory, require path, and gemspec name.")
            ask(colors.green("Gem name"), required: true)
          end

          @module_name = CommandKit::Inflector.camelize(@gem_name)
          @author = options[:author]
          @email = options[:email]

          @summary = options[:summary] || begin
            puts
            puts colors.bright_black("A short (one line) summary of what your gem does.")
            ask(colors.green("Summary"), default: "A new Ruby gem")
          end

          @ruby_version = options[:ruby_version]

          @test_framework = options[:test] || begin
            puts
            puts colors.bright_black("Choose a test framework for your gem:")
            puts "  * #{colors.bold("Minitest")} - https://github.com/minitest/minitest"
            puts "  * #{colors.bold("RSpec")}    - https://rspec.info"
            ask_multiple_choice(colors.green("Test framework"), {"minitest" => :minitest, "rspec" => :rspec})
          end

          unless options.has_key?(:exe)
            puts
            puts colors.bright_black("An executable in exe/ lets users run your gem from the command line.")
            options[:exe] = ask_yes_or_no(colors.green("Create an executable"), default: false)
          end

          unless options.has_key?(:git)
            puts
            puts colors.bright_black("Initialize a git repository with an initial commit.")
            options[:git] = ask_yes_or_no(colors.green("Initialize git repo"), default: true)
          end

          if options[:git]
            @branch = options[:branch] || begin
              puts
              puts colors.bright_black("The default branch name for the new git repository.")
              ask(colors.green("Branch name"), default: "master")
            end
          end

          puts
          puts colors.bright_white("Creating gem '") + colors.bold(colors.cyan(@gem_name)) + colors.bright_white("'...")
          puts

          # Directory structure
          mkdir @gem_name
          mkdir "#{@gem_name}/lib"
          mkdir "#{@gem_name}/lib/#{@gem_name}"
          mkdir "#{@gem_name}/bin"
          mkdir "#{@gem_name}/exe" if options[:exe]

          if @test_framework == :rspec
            mkdir "#{@gem_name}/spec"
          else
            mkdir "#{@gem_name}/test"
          end

          # Core files
          erb "gemspec.erb",                  "#{@gem_name}/#{@gem_name}.gemspec"
          erb "Gemfile.erb",                  "#{@gem_name}/Gemfile"
          erb "Rakefile.erb",                 "#{@gem_name}/Rakefile"
          erb "README.md.erb",               "#{@gem_name}/README.md"
          erb "LICENSE.txt.erb",             "#{@gem_name}/LICENSE.txt"
          erb "lib/gem_name.rb.erb",         "#{@gem_name}/lib/#{@gem_name}.rb"
          erb "lib/gem_name/version.rb.erb", "#{@gem_name}/lib/#{@gem_name}/version.rb"

          # Test files
          if @test_framework == :rspec
            erb "spec/spec_helper.rb.erb",   "#{@gem_name}/spec/spec_helper.rb"
            erb "spec/gem_name_spec.rb.erb", "#{@gem_name}/spec/#{@gem_name.tr('-', '_')}_spec.rb"
            erb "spec/zeitwerk_spec.rb.erb", "#{@gem_name}/spec/zeitwerk_spec.rb"
            erb "rspec.erb",                 "#{@gem_name}/.rspec"
          else
            erb "test/test_helper.rb.erb",   "#{@gem_name}/test/test_helper.rb"
            erb "test/gem_name_test.rb.erb", "#{@gem_name}/test/#{@gem_name.tr('-', '_')}_test.rb"
            erb "test/zeitwerk_test.rb.erb", "#{@gem_name}/test/zeitwerk_test.rb"
          end

          # Dev files
          erb "bin/console.erb",             "#{@gem_name}/bin/console"
          erb "bin/setup.erb",               "#{@gem_name}/bin/setup"
          chmod "+x", "#{@gem_name}/bin/console"
          chmod "+x", "#{@gem_name}/bin/setup"

          # Config files
          erb "dotfiles/rubocop.yml.erb",    "#{@gem_name}/.rubocop.yml"
          cp "dotfiles/gitignore",           "#{@gem_name}/.gitignore"
          erb "dotfiles/ruby-version.erb",   "#{@gem_name}/.ruby-version"

          # Optional executable
          if options[:exe]
            erb "exe/gem_name.erb", "#{@gem_name}/exe/#{@gem_name}"
            chmod "+x", "#{@gem_name}/exe/#{@gem_name}"
          end

          # Bundle install
          cd @gem_name do
            sh "bundle", "install"
          end

          # Git init
          if options[:git]
            cd @gem_name do
              sh "git", "init", "-q", "-b", @branch
              sh "git", "add", "."
              sh "git", "commit", "-q", "-m", "Initial commit."
            end
          end
        end

        private

        def minor_version_for(version)
          version.split(".")[0..1].join(".")
        end
      end
    end
  end
end
