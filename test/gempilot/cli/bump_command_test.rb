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

      # --- Delegates to rake ---

      def test_bump_invokes_rake_version_bump_patch
        calls = recorded_system_calls { |cmd| cmd.main([]) }

        assert_includes calls, ["bundle", "exec", "rake", "version:bump[patch]"]
      end

      def test_bump_patch_explicit_invokes_rake
        calls = recorded_system_calls { |cmd| cmd.main(["patch"]) }

        assert_includes calls, ["bundle", "exec", "rake", "version:bump[patch]"]
      end

      def test_bump_minor_invokes_rake
        calls = recorded_system_calls { |cmd| cmd.main(["minor"]) }

        assert_includes calls, ["bundle", "exec", "rake", "version:bump[minor]"]
      end

      def test_bump_major_invokes_rake
        calls = recorded_system_calls { |cmd| cmd.main(["major"]) }

        assert_includes calls, ["bundle", "exec", "rake", "version:bump[major]"]
      end

      # --- Error handling (detected before rake delegation) ---

      def test_bump_fails_without_gemspec
        FileUtils.rm("my_gem.gemspec")
        stdout = StringIO.new
        command = Commands::Bump.new(stdout: stdout)
        exit_code = command.main([])

        assert_equal 1, exit_code
      end

      def test_bump_fails_with_invalid_segment
        exit_code = nil
        calls = recorded_system_calls { |cmd| exit_code = cmd.main(["hotfix"]) }

        assert_equal 1, exit_code
        assert_empty calls, "rake should not be called for an invalid segment"
      end

      private

      def recorded_system_calls
        calls = []
        command = Commands::Bump.new(stdout: StringIO.new)
        command.define_singleton_method(:system) do |*args|
          calls << args
          true
        end
        yield command
        calls
      end

      def run_bump_command(*args)
        stdout = StringIO.new
        Commands::Bump.new(stdout: stdout).main(args)
      end
    end
  end
end
