require "test_helper"
require "gempilot/cli"
require "tmpdir"
require "stringio"

module Gempilot
  class CLI
    class ConsoleCommandTest < Minitest::Test
      def setup
        @tmpdir = Dir.mktmpdir("console_command_test")
        @original_dir = Dir.pwd
        Dir.chdir(@tmpdir)
        File.write("my_gem.gemspec", 'Gem::Specification.new { |s| s.name = "my_gem" }')
        FileUtils.mkdir_p("test")
      end

      def teardown
        Dir.chdir(@original_dir)
        FileUtils.rm_rf(@tmpdir)
      end

      def test_console_fails_without_gemspec
        FileUtils.rm("my_gem.gemspec")
        stdout = StringIO.new
        command = Commands::Console.new(stdout: stdout)

        exit_code = command.main([])

        assert_equal 1, exit_code
      end

      def test_console_fails_without_bin_console
        stdout = StringIO.new
        command = Commands::Console.new(stdout: stdout)

        exit_code = command.main([])

        assert_equal 1, exit_code
      end
    end
  end
end
