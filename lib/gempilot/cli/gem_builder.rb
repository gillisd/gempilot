module Gempilot
  class CLI
    ## File rendering and directory creation logic for scaffolding a new gem.
    ##
    ## Expects the including class to provide Generator methods (+mkdir+, +erb+,
    ## +chmod+, +cp+, +cd+, +sh+) and the following instance variables:
    ## +@gem_name+, +@require_path+, +@module_name+, +@hyphenated+,
    ## +@test_framework+, +@branch+.
    module GemBuilder
      private

      def create_directories
        mkdir @gem_name
        mkdir "#{@gem_name}/lib"
        create_lib_subdirectories
        mkdir "#{@gem_name}/bin"
        mkdir "#{@gem_name}/exe" if options[:exe]
        create_test_directory
      end

      def create_lib_subdirectories
        @require_path.split("/").reduce("#{@gem_name}/lib") do |dir, part|
          path = "#{dir}/#{part}"
          mkdir path
          path
        end
      end

      def create_test_directory
        if @test_framework == :rspec
          mkdir "#{@gem_name}/spec"
        else
          mkdir "#{@gem_name}/test"
        end
      end

      def render_core_templates
        erb "gemspec.erb",                  "#{@gem_name}/#{@gem_name}.gemspec"
        erb "Gemfile.erb",                  "#{@gem_name}/Gemfile"
        erb "Rakefile.erb",                 "#{@gem_name}/Rakefile"
        erb "README.md.erb",               "#{@gem_name}/README.md"
        erb "LICENSE.txt.erb",             "#{@gem_name}/LICENSE.txt"
        erb "lib/gem_name.rb.erb",         "#{@gem_name}/lib/#{@gem_name}.rb"
        erb "lib/gem_name/version.rb.erb", "#{@gem_name}/lib/#{@require_path}/version.rb"
        erb "lib/gem_name_extension.rb.erb", "#{@gem_name}/lib/#{@require_path}.rb" if @hyphenated
        render_version_rake
      end

      def render_version_rake
        mkdir "#{@gem_name}/rakelib"
        erb "rakelib/version.rake.erb", "#{@gem_name}/rakelib/version.rake"
      end

      def render_test_templates
        if @test_framework == :rspec
          render_rspec_templates
        else
          render_minitest_templates
        end
      end

      def render_rspec_templates
        erb "spec/spec_helper.rb.erb",   "#{@gem_name}/spec/spec_helper.rb"
        erb "spec/gem_name_spec.rb.erb", "#{@gem_name}/spec/#{@gem_name.tr("-", "_")}_spec.rb"
        erb "spec/zeitwerk_spec.rb.erb", "#{@gem_name}/spec/zeitwerk_spec.rb"
        erb "rspec.erb",                 "#{@gem_name}/.rspec"
      end

      def render_minitest_templates
        erb "test/test_helper.rb.erb",   "#{@gem_name}/test/test_helper.rb"
        erb "test/gem_name_test.rb.erb", "#{@gem_name}/test/#{@gem_name.tr("-", "_")}_test.rb"
        erb "test/zeitwerk_test.rb.erb", "#{@gem_name}/test/zeitwerk_test.rb"
      end

      def render_dev_files
        erb "bin/console.erb", "#{@gem_name}/bin/console"
        erb "bin/setup.erb",   "#{@gem_name}/bin/setup"
        chmod "+x", "#{@gem_name}/bin/console"
        chmod "+x", "#{@gem_name}/bin/setup"
      end

      def render_config_files
        erb "dotfiles/rubocop.yml.erb",  "#{@gem_name}/.rubocop.yml"
        cp "dotfiles/gitignore",         "#{@gem_name}/.gitignore"
        erb "dotfiles/ruby-version.erb", "#{@gem_name}/.ruby-version"
        render_ci_workflow
      end

      def render_ci_workflow
        mkdir "#{@gem_name}/.github"
        mkdir "#{@gem_name}/.github/workflows"
        erb "dotfiles/github/workflows/ci.yml.erb", "#{@gem_name}/.github/workflows/ci.yml"
      end

      def render_executable
        return unless options[:exe]

        erb "exe/gem_name.erb", "#{@gem_name}/exe/#{@gem_name}"
        chmod "+x", "#{@gem_name}/exe/#{@gem_name}"
      end

      def run_bundle_install
        cd @gem_name do
          sh "bundle", "install"
        end
      end

      def initialize_git_repo
        return unless options[:git]

        cd @gem_name do
          sh "git", "init", "-q", "-b", @branch
          sh "git", "add", "."
          sh "git", "commit", "-q", "-m", "Initial commit."
        end
      end
    end
  end
end
