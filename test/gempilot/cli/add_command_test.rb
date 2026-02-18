require "test_helper"
require "gempilot/cli"
require "tmpdir"
require "stringio"

module Gempilot
  class CLI
    class AddCommandTest < Minitest::Test
      def setup
        @tmpdir = Dir.mktmpdir("add_command_test")
        @original_dir = Dir.pwd

        Dir.chdir(@tmpdir)
        FileUtils.mkdir_p("lib/my_gem")
        FileUtils.mkdir_p("test")
        File.write("my_gem.gemspec", 'Gem::Specification.new { |s| s.name = "my_gem" }')
      end

      def teardown
        Dir.chdir(@original_dir)
        FileUtils.rm_rf(@tmpdir)
      end

      # --- Class generation ---

      def test_add_class_creates_lib_file
        run_add_command("class", "authentication")
        assert_path_exists "lib/my_gem/authentication.rb"
      end

      def test_add_class_creates_correct_module_nesting
        run_add_command("class", "authentication")
        content = File.read("lib/my_gem/authentication.rb")
        assert_includes content, "module MyGem"
        assert_includes content, "class Authentication"
      end

      def test_add_class_with_nested_path_creates_directories
        run_add_command("class", "services/authentication")
        assert File.directory?("lib/my_gem/services")
        assert_path_exists "lib/my_gem/services/authentication.rb"
      end

      def test_add_class_with_nested_path_has_correct_nesting
        run_add_command("class", "services/authentication")
        content = File.read("lib/my_gem/services/authentication.rb")
        assert_includes content, "module MyGem"
        assert_includes content, "module Services"
        assert_includes content, "class Authentication"
      end

      def test_add_class_with_deeply_nested_path
        run_add_command("class", "services/auth/token_validator")
        content = File.read("lib/my_gem/services/auth/token_validator.rb")
        assert_includes content, "module MyGem"
        assert_includes content, "module Services"
        assert_includes content, "module Auth"
        assert_includes content, "class TokenValidator"
      end

      def test_add_class_creates_frozen_string_literal
        run_add_command("class", "authentication")
        content = File.read("lib/my_gem/authentication.rb")
        assert content.start_with?("# frozen_string_literal: true")
      end

      # --- Test file generation ---

      def test_add_class_creates_minitest_file
        run_add_command("class", "authentication")
        assert_path_exists "test/my_gem/authentication_test.rb"
        content = File.read("test/my_gem/authentication_test.rb")
        assert_includes content, 'require "test_helper"'
        assert_includes content, "module MyGem"
        assert_includes content, "Minitest::Test"
      end

      def test_add_class_creates_rspec_file_when_spec_dir_exists
        FileUtils.rm_rf("test")
        FileUtils.mkdir_p("spec")
        run_add_command("class", "authentication")
        assert_path_exists "spec/my_gem/authentication_spec.rb"
        content = File.read("spec/my_gem/authentication_spec.rb")
        assert_includes content, 'require "spec_helper"'
        assert_includes content, "RSpec.describe MyGem::Authentication"
      end

      def test_add_class_creates_nested_test_file
        run_add_command("class", "services/authentication")
        assert_path_exists "test/my_gem/services/authentication_test.rb"
      end

      # --- Module generation ---

      def test_add_module_creates_lib_file
        run_add_command("module", "middleware")
        assert_path_exists "lib/my_gem/middleware.rb"
        content = File.read("lib/my_gem/middleware.rb")
        assert_includes content, "module MyGem"
        assert_includes content, "module Middleware"
        refute_includes content, "class"
      end

      def test_add_module_does_not_create_test_file
        run_add_command("module", "middleware")
        refute_path_exists "test/my_gem/middleware_test.rb"
      end

      def test_add_module_with_nested_path
        run_add_command("module", "services/concerns")
        content = File.read("lib/my_gem/services/concerns.rb")
        assert_includes content, "module MyGem"
        assert_includes content, "module Services"
        assert_includes content, "module Concerns"
      end

      # --- Command generation ---

      def test_add_command_creates_command_file
        FileUtils.mkdir_p("lib/my_gem/cli/commands")
        run_add_command("command", "deploy")

        assert_path_exists "lib/my_gem/cli/commands/deploy.rb"

        content = File.read("lib/my_gem/cli/commands/deploy.rb")

        assert_includes content, "class Deploy < Command"
        assert_includes content, "module MyGem"
        assert_includes content, "module Commands"
        assert_includes content, "description"
      end

      # --- Error handling ---

      def test_add_fails_without_gemspec
        FileUtils.rm("my_gem.gemspec")
        stdout = StringIO.new
        command = Commands::Add.new(stdout: stdout)

        exit_code = command.main(["class", "foo"])

        assert_equal 1, exit_code
      end

      def test_add_fails_with_unknown_type
        stdout = StringIO.new
        command = Commands::Add.new(stdout: stdout)

        exit_code = command.main(["widget", "foo"])

        assert_equal 1, exit_code
      end

      private

      def run_add_command(type, path)
        stdout = StringIO.new
        command = Commands::Add.new(stdout: stdout)
        command.main([type, path])
      end
    end
  end
end
