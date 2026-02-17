
require "test_helper"
require "gempilot/cli/command"
require "gempilot/cli/generator"
require "tmpdir"
require "stringio"

module Gempilot
  class CLI
    class GeneratorTest < Minitest::Test
      class TestGenerator < Command
        include Generator

        template_dir File.join(Gempilot::ROOT, "data", "templates", "gem")
      end

      def setup
        @tmpdir = Dir.mktmpdir("generator_test")
        @stdout = StringIO.new
        @generator = TestGenerator.new(stdout: @stdout)
      end

      def teardown
        FileUtils.rm_rf(@tmpdir)
      end

      def test_template_dir_is_set
        expected = File.join(Gempilot::ROOT, "data", "templates", "gem")
        assert_equal expected, @generator.template_dir
      end

      def test_mkdir_creates_directory
        path = File.join(@tmpdir, "new_dir")
        @generator.mkdir(path)
        assert File.directory?(path)
      end

      def test_mkdir_prints_action
        @generator.mkdir(File.join(@tmpdir, "new_dir"))
        assert_includes @stdout.string, "mkdir"
      end

      def test_touch_creates_file
        path = File.join(@tmpdir, "new_file")
        @generator.touch(path)
        assert File.exist?(path)
      end

      def test_cp_copies_from_template_dir
        dest = File.join(@tmpdir, ".rubocop.yml")
        @generator.cp(".rubocop.yml", dest)
        assert File.exist?(dest)
        refute_empty File.read(dest)
      end

      def test_erb_renders_template
        @generator.instance_variable_set(:@gem_name, "test_gem")
        @generator.instance_variable_set(:@module_name, "TestGem")
        @generator.instance_variable_set(:@ruby_version, "3.4.8")

        dest = File.join(@tmpdir, "version.rb")
        @generator.erb("lib/gem_name/version.rb.erb", dest)

        content = File.read(dest)
        assert_includes content, "module TestGem"
        assert_includes content, 'VERSION = "0.1.0"'
      end

      def test_chmod_changes_permissions
        path = File.join(@tmpdir, "script")
        File.write(path, "#!/bin/sh\n")
        @generator.chmod("+x", path)
        assert File.executable?(path)
      end

      def test_sh_runs_command
        result = @generator.sh("true")
        assert result
      end
    end
  end
end
