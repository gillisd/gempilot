require "test_helper"
require "tmpdir"
require "stringio"

module Gempilot
  class CLI
    class BumpCommandTest < Minitest::Test
      include FileUtils

      def setup
        @tmpdir = Dir.mktmpdir("bump_command_test")
        @original_dir = Dir.pwd
        Dir.chdir(@tmpdir)
        File.write("my_gem.gemspec", 'Gem::Specification.new { |s| s.name = "my_gem" }')
        mkdir_p("lib/my_gem")
        File.write("lib/my_gem/version.rb", <<~RUBY)
          module MyGem
            VERSION = "1.2.3".freeze
          end
        RUBY
      end

      def teardown
        Dir.chdir(@original_dir)
        rm_rf(@tmpdir)
      end

      # --- Error handling (detected before rake delegation) ---

      def test_bump_fails_without_gemspec
        rm("my_gem.gemspec")
        stdout = StringIO.new
        command = Commands::Bump.new(stdout: stdout)
        exit_code = command.main([])

        assert_equal 1, exit_code
      end

      def test_bump_fails_with_invalid_segment
        exit_code = Shell.with_gateway(Shell::StubGateway.new) { Commands::Bump.new(stdout: StringIO.new).main(["hotfix"]) }

        assert_equal 1, exit_code
      end

      def test_bump_runs_nothing_for_an_invalid_segment
        stubs = Shell::StubGateway.new

        Shell.with_gateway(stubs) { Commands::Bump.new(stdout: StringIO.new).main(["hotfix"]) }

        assert_empty stubs.invocations
      end
    end
  end
end
