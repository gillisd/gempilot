
require_relative "../command"
require_relative "../generator"

module Gempilot
  class CLI
    module Commands
      class New < Command
        include Generator

        template_dir File.join(Gempilot::ROOT, "data", "templates", "gem")

        usage "[options] GEM_NAME"

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
                        type: { "minitest" => :minitest, "rspec" => :rspec },
                        default: :minitest
                      },
                      desc: "Test framework"

        option :exe, desc: "Create an executable"

        option :git, desc: "Initialize git repo"

        argument :gem_name, required: true,
                            desc: "Name of the gem"

        description "Create a new gem"

        def run(gem_name)
          @gem_name = gem_name
          @module_name = inflect_module(gem_name)
          @author = options[:author]
          @email = options[:email]
          @summary = options[:summary] || "TODO: Write a summary"
          @ruby_version = options[:ruby_version]
          @test_framework = options[:test]

          # Directory structure
          mkdir gem_name
          mkdir "#{gem_name}/lib"
          mkdir "#{gem_name}/lib/#{gem_name}"
          mkdir "#{gem_name}/test"
          mkdir "#{gem_name}/bin"
          mkdir "#{gem_name}/exe" if options[:exe]

          # Core files
          erb "gemspec.erb",                  "#{gem_name}/#{gem_name}.gemspec"
          erb "Gemfile.erb",                  "#{gem_name}/Gemfile"
          erb "Rakefile.erb",                 "#{gem_name}/Rakefile"
          erb "README.md.erb",               "#{gem_name}/README.md"
          erb "LICENSE.txt.erb",             "#{gem_name}/LICENSE.txt"
          erb "lib/gem_name.rb.erb",         "#{gem_name}/lib/#{gem_name}.rb"
          erb "lib/gem_name/version.rb.erb", "#{gem_name}/lib/#{gem_name}/version.rb"

          # Dev files
          erb "test/test_helper.rb.erb",     "#{gem_name}/test/test_helper.rb"
          erb "test/gem_name_test.rb.erb",   "#{gem_name}/test/#{gem_name.tr('-', '_')}_test.rb"
          erb "bin/console.erb",             "#{gem_name}/bin/console"
          erb "bin/setup.erb",               "#{gem_name}/bin/setup"
          chmod "+x", "#{gem_name}/bin/console"
          chmod "+x", "#{gem_name}/bin/setup"

          # Config files
          cp "dotfiles/rubocop.yml.erb",                 "#{gem_name}/.rubocop.yml"
          cp "dotfiles/gitignore",                   "#{gem_name}/.gitignore"
          erb "dotfiles/ruby-version.erb",           "#{gem_name}/.ruby-version"

          # Optional executable
          if options[:exe]
            erb "exe/gem_name.erb", "#{gem_name}/exe/#{gem_name}"
            chmod "+x", "#{gem_name}/exe/#{gem_name}"
          end

          # Bundle install
          cd gem_name do
            sh "bundle", "install"
          end

          # Git init
          if options[:git]
            cd gem_name do
              sh "git", "init", "-q", "-b", "main"
              sh "git", "add", "."
              sh "git", "commit", "-q", "-m", "Initial commit."
            end
          end
        end

        private

        def inflect_module(name)
          name.split(/[-_]/).map(&:capitalize).join
        end
      end
    end
  end
end
