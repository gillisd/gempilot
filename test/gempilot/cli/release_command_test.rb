require "test_helper"
require "gempilot/cli"
require "tmpdir"
require "stringio"

module Gempilot
  class CLI
    class ReleaseCommandTest < Minitest::Test
      def setup
        @tmpdir = Dir.mktmpdir("release_command_test")
        @original_dir = Dir.pwd
        Dir.chdir(@tmpdir)
        File.write("my_gem.gemspec", 'Gem::Specification.new { |s| s.name = "my_gem" }')
        FileUtils.mkdir_p("test")
      end

      def teardown
        Dir.chdir(@original_dir)
        FileUtils.rm_rf(@tmpdir)
      end

      def test_release_fails_without_gemspec
        FileUtils.rm("my_gem.gemspec")
        stdout = StringIO.new
        command = Commands::Release.new(stdout: stdout)

        exit_code = command.main([])

        assert_equal 1, exit_code
      end

      def test_release_delegates_to_rake_release
        system_calls = []
        stdout = StringIO.new
        command = Commands::Release.new(stdout: stdout)
        command.define_singleton_method(:system) do |*args|
          system_calls << args
          true
        end
        command.main([])

        assert system_calls.any? { |call| call.include?("rake") && call.include?("release") },
               "Expected rake release to be called"
      end
    end
  end
end
