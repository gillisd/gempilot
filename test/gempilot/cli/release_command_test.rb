require "test_helper"
require "tmpdir"
require "stringio"

module Gempilot
  class CLI
    class ReleaseCommandTest < Minitest::Test
      include FileUtils

      def setup
        @tmpdir = Dir.mktmpdir("release_command_test")
        @original_dir = Dir.pwd
        Dir.chdir(@tmpdir)
        File.write("my_gem.gemspec", 'Gem::Specification.new { |s| s.name = "my_gem" }')
        mkdir_p("test")
      end

      def teardown
        Dir.chdir(@original_dir)
        rm_rf(@tmpdir)
      end

      def test_release_fails_without_gemspec
        rm("my_gem.gemspec")
        stdout = StringIO.new
        command = Commands::Release.new(stdout: stdout)

        exit_code = command.main([])

        assert_equal 1, exit_code
      end

      # rake release publishes the gem, so these stub it.
      def test_release_runs_rake_release
        stubs = release_stubs

        Shell.with_gateway(stubs) { Commands::Release.new(stdout: StringIO.new).main([]) }

        assert stubs.ran?("bundle", "exec", "rake", "release")
      end

      def test_release_runs_rake_outside_gempilots_bundle
        stubs = release_stubs

        Shell.with_gateway(stubs) { Commands::Release.new(stdout: StringIO.new).main([]) }

        assert_predicate stubs.invocations.last, :unbundled
      end

      def test_release_exits_1_when_rake_release_fails
        stubs = release_stubs(exitstatus: 1)

        exit_code = Shell.with_gateway(stubs) { Commands::Release.new(stdout: StringIO.new).main([]) }

        assert_equal 1, exit_code
      end

      private

      def release_stubs(exitstatus: 0)
        Shell::StubGateway.new.tap do |stubs|
          stubs.stub("bundle", "exec", "rake", "release").to_return(exitstatus:)
        end
      end
    end
  end
end
