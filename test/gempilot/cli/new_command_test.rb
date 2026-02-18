require "test_helper"
require "gempilot/cli"
require "tmpdir"
require "stringio"

module Gempilot
  class CLI
    class NewCommandTest < Minitest::Test
      def setup
        @tmpdir = Dir.mktmpdir("new_command_test")
        @original_dir = Dir.pwd
        Dir.chdir(@tmpdir)
      end

      def teardown
        Dir.chdir(@original_dir)
        FileUtils.rm_rf(@tmpdir)
      end

      def test_creates_gem_directory_structure
        run_new_command("test_gem")

        assert File.directory?("test_gem")
        assert File.directory?("test_gem/lib")
        assert File.directory?("test_gem/lib/test_gem")
        assert File.directory?("test_gem/test")
        assert File.directory?("test_gem/bin")
      end

      def test_creates_gemspec
        run_new_command("test_gem")

        gemspec = File.read("test_gem/test_gem.gemspec")

        assert_includes gemspec, 'spec.name = "test_gem"'
        assert_includes gemspec, "TestGem::VERSION"
        assert_includes gemspec, '"Test Author"'
        assert_includes gemspec, '"test@example.com"'
        assert_includes gemspec, '"A test gem"'
        refute_includes gemspec, "TODO"
      end

      def test_creates_lib_with_zeitwerk
        run_new_command("test_gem")

        main_rb = File.read("test_gem/lib/test_gem.rb")

        assert_includes main_rb, 'require "zeitwerk"'
        assert_includes main_rb, "Zeitwerk::Loader.for_gem"
        assert_includes main_rb, "module TestGem"
      end

      def test_creates_version_file
        run_new_command("test_gem")

        version_rb = File.read("test_gem/lib/test_gem/version.rb")

        assert_includes version_rb, "module TestGem"
        assert_includes version_rb, 'VERSION = "0.0.1"'
      end

      def test_creates_test_helper
        run_new_command("test_gem")

        test_helper = File.read("test_gem/test/test_helper.rb")

        assert_includes test_helper, "minitest/autorun"
        assert_includes test_helper, "minitest/reporters"
        assert_includes test_helper, 'require "test_gem"'
      end

      def test_creates_test_file
        run_new_command("test_gem")

        test_file = File.read("test_gem/test/test_gem_test.rb")

        assert_includes test_file, "class TestGemTest < Minitest::Test"
        assert_includes test_file, "TestGem::VERSION"
      end

      def test_bin_scripts_are_executable
        run_new_command("test_gem")

        assert File.executable?("test_gem/bin/console")
        assert File.executable?("test_gem/bin/setup")
      end

      def test_creates_config_files
        run_new_command("test_gem")

        assert_path_exists "test_gem/.rubocop.yml"
        assert_path_exists "test_gem/.gitignore"
        assert_path_exists "test_gem/.ruby-version"
      end

      def test_exe_flag_creates_executable
        run_new_command("test_gem", "--exe")

        assert File.directory?("test_gem/exe")
        assert_path_exists "test_gem/exe/test_gem"
        assert File.executable?("test_gem/exe/test_gem")
      end

      def test_inflects_module_name_correctly
        run_new_command("my_cool_gem")

        version_rb = File.read("my_cool_gem/lib/my_cool_gem/version.rb")

        assert_includes version_rb, "module MyCoolGem"
      end

      def test_rubocop_yml_is_valid_yaml
        run_new_command("test_gem")

        content = File.read("test_gem/.rubocop.yml")

        refute_includes content, "<%"
        assert_includes content, "rubocop-minitest"
      end

      # RSpec support tests

      def test_rspec_creates_spec_directory
        run_new_command("test_gem", "--test", "rspec")

        assert File.directory?("test_gem/spec")
        refute File.directory?("test_gem/test")
      end

      def test_rspec_creates_spec_files
        run_new_command("test_gem", "--test", "rspec")

        assert_path_exists "test_gem/spec/spec_helper.rb"
        assert_path_exists "test_gem/spec/test_gem_spec.rb"
        assert_path_exists "test_gem/.rspec"
      end

      def test_rspec_spec_helper_content
        run_new_command("test_gem", "--test", "rspec")

        helper = File.read("test_gem/spec/spec_helper.rb")

        assert_includes helper, 'require "test_gem"'
        assert_includes helper, "RSpec.configure"
        assert_includes helper, "disable_monkey_patching!"
      end

      def test_rspec_spec_file_content
        run_new_command("test_gem", "--test", "rspec")

        spec_file = File.read("test_gem/spec/test_gem_spec.rb")

        assert_includes spec_file, "RSpec.describe TestGem"
        assert_includes spec_file, "TestGem::VERSION"
      end

      def test_rspec_gemfile_has_rspec_gem
        run_new_command("test_gem", "--test", "rspec")

        gemfile = File.read("test_gem/Gemfile")

        assert_includes gemfile, 'gem "rspec"'
        refute_includes gemfile, 'gem "minitest"'
      end

      def test_rspec_rakefile_has_rspec_task
        run_new_command("test_gem", "--test", "rspec")

        rakefile = File.read("test_gem/Rakefile")

        assert_includes rakefile, "rspec/core/rake_task"
        assert_includes rakefile, ":spec"
        refute_includes rakefile, "minitest"
      end

      def test_rspec_rubocop_has_rspec_plugin
        run_new_command("test_gem", "--test", "rspec")

        rubocop = File.read("test_gem/.rubocop.yml")

        assert_includes rubocop, "rubocop-rspec"
        refute_includes rubocop, "rubocop-minitest"
      end

      private

      def run_new_command(gem_name, *extra_args)
        stdout = StringIO.new
        args = [
          "--author", "Test Author",
          "--email", "test@example.com",
          "--summary", "A test gem",
          "--ruby-version", "3.4.8",
          *extra_args,
          gem_name
        ]

        command = Commands::New.new(stdout: stdout)
        # Stub bundle install to avoid network calls in tests
        command.define_singleton_method(:sh) do |cmd, *arguments|
          # Skip actual shell commands in tests
        end
        command.main(args)
      end
    end
  end
end
