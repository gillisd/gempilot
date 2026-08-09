require "test_helper"
require "tmpdir"
require "stringio"

module Gempilot
  class CLI
    class SetupCommandTest < Minitest::Test
      def setup
        @tmpdir = Dir.mktmpdir("setup_command_test")
        @original_dir = Dir.pwd
        Dir.chdir(@tmpdir)
        FileUtils.mkdir_p("lib/my_gem")
        FileUtils.mkdir_p("bin")
        File.write("my_gem.gemspec", 'Gem::Specification.new { |s| s.name = "my_gem" }')
        File.write("Rakefile", <<~RAKEFILE)
          require "bundler/gem_tasks"

          task default: :test
        RAKEFILE
        File.write("bin/setup", "#!/usr/bin/env bash\nbundle install\n")
      end

      def teardown
        Dir.chdir(@original_dir)
        FileUtils.rm_rf(@tmpdir)
      end

      def test_setup_betterleaks_creates_executable_hook
        run_setup_command("betterleaks")

        assert_path_exists ".githooks/pre-commit"
        assert_predicate Pathname(".githooks/pre-commit"), :executable?
        assert_includes File.read(".githooks/pre-commit"), "betterleaks git --pre-commit"
      end

      def test_setup_betterleaks_creates_ci_workflow
        run_setup_command("betterleaks")

        assert_path_exists ".github/workflows/secrets.yml"
        assert_includes File.read(".github/workflows/secrets.yml"), "betterleaks"
      end

      def test_setup_betterleaks_wires_rakefile
        run_setup_command("betterleaks")

        rakefile = File.read("Rakefile")

        assert_includes rakefile, 'require "gempilot/betterleaks_task"'
        assert_includes rakefile, "Gempilot::BetterleaksTask.new"
        assert_operator rakefile.index("Gempilot::BetterleaksTask.new"), :<,
                        rakefile.index("task default"),
                        "betterleaks wiring should sit above the default task"
      end

      def test_setup_betterleaks_wires_bin_setup
        run_setup_command("betterleaks")

        assert_includes File.read("bin/setup"), "git config core.hooksPath .githooks"
      end

      def test_setup_betterleaks_is_idempotent
        run_setup_command("betterleaks")

        stdout = StringIO.new
        command = Commands::Setup.new(stdout: stdout)
        command.define_singleton_method(:sh) { |*_args| nil }
        exit_code = command.main(["betterleaks"])

        rakefile = File.read("Rakefile")

        assert_equal 0, exit_code
        assert_equal 1, rakefile.scan("Gempilot::BetterleaksTask.new").size
        assert_equal 1, File.read("bin/setup").scan("core.hooksPath").size
        assert_includes stdout.string, "skip"
      end

      def test_setup_fails_without_gemspec
        FileUtils.rm("my_gem.gemspec")
        stdout = StringIO.new
        command = Commands::Setup.new(stdout: stdout)
        command.define_singleton_method(:sh) { |*_args| nil }

        assert_equal 1, command.main(["betterleaks"])
      end

      def test_setup_fails_with_unknown_feature
        stdout = StringIO.new
        command = Commands::Setup.new(stdout: stdout)
        command.define_singleton_method(:sh) { |*_args| nil }

        assert_equal 1, command.main(["widget"])
      end

      private

      def run_setup_command(*args)
        stdout = StringIO.new
        command = Commands::Setup.new(stdout: stdout)
        # Stub sh so `git config core.hooksPath` is not run against the non-repo tmpdir.
        command.define_singleton_method(:sh) { |*_args| nil }
        command.main(args)
      end
    end
  end
end
