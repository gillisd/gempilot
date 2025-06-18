module Gempilot
  module CommandMappers
    class Bundle < CommandMapper::Command
      command "bundle" do
        # Subcommand for 'gem'
        subcommand "gem" do
          # Binary/executable options
          option "--exe", name: :exe
          option "-b", name: :bin
          option "--bin", name: :bin_long
          option "--no-exe", name: :no_exe

          # Code of Conduct options
          option "--coc", name: :coc
          option "--no-coc", name: :no_coc

          # Changelog options
          option "--changelog", name: :changelog
          option "--no-changelog", name: :no_changelog

          # Extension options
          option "--ext", name: :ext, value: { required: false }, equals: true
          option "--no-ext", name: :no_ext

          # Git options
          option "--git", name: :git

          # GitHub username
          option "--github-username", name: :github_username, value: true, equals: true

          # MIT License options
          option "--mit", name: :mit
          option "--no-mit", name: :no_mit

          # Test framework options
          option "-t", name: :test_short, value: true
          option "--test", name: :test, value: { required: false }, equals: true
          option "--no-test", name: :no_test

          # Continuous Integration options
          option "--ci", name: :ci, value: { required: false }, equals: true
          option "--no-ci", name: :no_ci

          # Linter options
          option "--linter", name: :linter, value: { required: false }, equals: true
          option "--no-linter", name: :no_linter

          # RuboCop (legacy option)
          option "--rubocop", name: :rubocop

          # Editor options
          option "-e", name: :edit_short, value: { required: false }, equals: true
          option "--edit", name: :edit, value: { required: false }, equals: true

          # The gem name argument
          argument :gem_name, required: true, type: CommandMapper::Types::Str.new
        end
      end

      def capture_command
        runner = Runner.new(command_string)
        runner.run
      end

      # Convenience methods for test frameworks
      def minitest!
        gem.test = "minitest"
      end

      def rspec!
        gem.test = "rspec"
      end

      def test_unit!
        gem.test = "test-unit"
      end

      # Convenience methods for CI services
      def github_ci!
        gem.ci = "github"
      end

      def gitlab_ci!
        gem.ci = "gitlab"
      end

      def circle_ci!
        gem.ci = "circle"
      end

      # Convenience methods for linters
      def rubocop_linter!
        gem.linter = "rubocop"
      end

      def standard_linter!
        gem.linter = "standard"
      end

      # Convenience methods for extensions
      def c_extension!
        gem.ext = "c"
      end

      def rust_extension!
        gem.ext = "rust"
      end

      # Convenience method to enable binary creation
      def with_binary!
        gem.exe = true
      end

      # Convenience method to enable MIT license
      def with_mit_license!
        gem.mit = true
      end

      # Convenience method to enable Code of Conduct
      def with_coc!
        gem.coc = true
      end

      # Convenience method to enable Changelog
      def with_changelog!
        gem.changelog = true
      end

      # Convenience method to enable Git initialization
      def with_git!
        gem.git = true
      end

      # Convenience method to set GitHub username
      def github_username=(username)
        gem.github_username = username
      end

      # Convenience method to enable RuboCop (legacy)
      def with_rubocop!
        gem.rubocop = true
      end

      # Convenience method to enable C extensions (alias)
      def with_extensions!
        gem.ext = true
      end

      # Method to set the gem name
      def gem_name=(name)
        gem.gem_name = name
      end

      def gem_name
        gem.gem_name
      end

      # Method to set editor
      def editor=(editor_name)
        gem.edit = editor_name
      end

      # Disable methods for convenience
      def no_tests!
        gem.no_test = true
      end

      def no_ci!
        gem.no_ci = true
      end

      def no_linter!
        gem.no_linter = true
      end

      def no_extensions!
        gem.no_ext = true
      end

      def no_mit!
        gem.no_mit = true
      end

      def no_coc!
        gem.no_coc = true
      end

      def no_changelog!
        gem.no_changelog = true
      end

      def no_exe!
        gem.no_exe = true
      end
    end
  end
end