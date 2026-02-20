require "test_helper"
require "gempilot/cli"
require "tmpdir"
require "stringio"

module Gempilot
  class CLI
    class BumpCommandTest < Minitest::Test
      def setup
        @tmpdir = Dir.mktmpdir("bump_command_test")
        @original_dir = Dir.pwd
        Dir.chdir(@tmpdir)
        File.write("my_gem.gemspec", 'Gem::Specification.new { |s| s.name = "my_gem" }')
        FileUtils.mkdir_p("lib/my_gem")
        File.write("lib/my_gem/version.rb", <<~RUBY)
          module MyGem
            VERSION = "1.2.3".freeze
          end
        RUBY
      end

      def teardown
        Dir.chdir(@original_dir)
        FileUtils.rm_rf(@tmpdir)
      end

      # --- Default (patch) bumping ---

      def test_bump_defaults_to_patch
        run_bump_command
        content = File.read("lib/my_gem/version.rb")

        assert_includes content, 'VERSION = "1.2.4"'
      end

      def test_bump_patch_explicit
        run_bump_command("patch")
        content = File.read("lib/my_gem/version.rb")

        assert_includes content, 'VERSION = "1.2.4"'
      end

      # --- Minor bumping ---

      def test_bump_minor
        run_bump_command("minor")
        content = File.read("lib/my_gem/version.rb")

        assert_includes content, 'VERSION = "1.3.0"'
      end

      # --- Major bumping ---

      def test_bump_major
        run_bump_command("major")
        content = File.read("lib/my_gem/version.rb")

        assert_includes content, 'VERSION = "2.0.0"'
      end

      # --- Preserves file structure ---

      def test_bump_preserves_module_wrapper
        run_bump_command("patch")
        content = File.read("lib/my_gem/version.rb")

        assert_includes content, "module MyGem"
        assert_includes content, "end"
      end

      def test_bump_preserves_freeze
        run_bump_command("patch")
        content = File.read("lib/my_gem/version.rb")

        assert_includes content, ".freeze"
      end

      # --- Version without .freeze ---

      def test_bump_works_without_freeze
        File.write("lib/my_gem/version.rb", <<~RUBY)
          module MyGem
            VERSION = "0.1.0"
          end
        RUBY
        run_bump_command("patch")
        content = File.read("lib/my_gem/version.rb")

        assert_includes content, 'VERSION = "0.1.1"'
      end

      # --- Error handling ---

      def test_bump_fails_without_gemspec
        FileUtils.rm("my_gem.gemspec")
        stdout = StringIO.new
        command = Commands::Bump.new(stdout: stdout)
        exit_code = command.main([])

        assert_equal 1, exit_code
      end

      def test_bump_fails_without_version_file
        FileUtils.rm("lib/my_gem/version.rb")
        stdout = StringIO.new
        command = Commands::Bump.new(stdout: stdout)
        exit_code = command.main([])

        assert_equal 1, exit_code
      end

      def test_bump_fails_with_invalid_segment
        stdout = StringIO.new
        command = Commands::Bump.new(stdout: stdout)
        exit_code = command.main(["hotfix"])

        assert_equal 1, exit_code
      end

      def test_bump_fails_with_no_version_constant
        File.write("lib/my_gem/version.rb", <<~RUBY)
          module MyGem
            # no version here
          end
        RUBY
        stdout = StringIO.new
        command = Commands::Bump.new(stdout: stdout)
        exit_code = command.main([])

        assert_equal 1, exit_code
      end

      # --- Output ---

      def test_bump_displays_old_and_new_version
        stdout = StringIO.new
        command = Commands::Bump.new(stdout: stdout)
        command.main(["patch"])
        output = stdout.string

        assert_includes output, "1.2.3"
        assert_includes output, "1.2.4"
      end

      private

      def run_bump_command(*args)
        stdout = StringIO.new
        command = Commands::Bump.new(stdout: stdout)
        command.main(args)
      end
    end
  end
end
