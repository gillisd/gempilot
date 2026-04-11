require "test_helper"
require "tmpdir"
require "stringio"

module Gempilot
  class CLI
    class NewCommandTest < Minitest::Test
      def setup
        @tmpdir = Dir.mktmpdir("new_command_test")
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

      def test_new_class_creates_lib_file
        run_new_command("class", "MyGem::Authentication")

        assert_path_exists "lib/my_gem/authentication.rb"
      end

      def test_new_class_creates_correct_module_nesting
        run_new_command("class", "MyGem::Authentication")
        content = File.read("lib/my_gem/authentication.rb")

        assert_includes content, "module MyGem"
        assert_includes content, "class Authentication"
      end

      def test_new_class_with_nested_constant_creates_directories
        run_new_command("class", "MyGem::Services::Authentication")

        assert_predicate Pathname("lib/my_gem/services"), :directory?
        assert_path_exists "lib/my_gem/services/authentication.rb"
      end

      def test_new_class_with_nested_constant_has_correct_nesting
        run_new_command("class", "MyGem::Services::Authentication")
        content = File.read("lib/my_gem/services/authentication.rb")

        assert_includes content, "module MyGem"
        assert_includes content, "module Services"
        assert_includes content, "class Authentication"
      end

      def test_new_class_with_deeply_nested_constant
        run_new_command("class", "MyGem::Services::Auth::TokenValidator")
        content = File.read("lib/my_gem/services/auth/token_validator.rb")

        assert_includes content, "module MyGem"
        assert_includes content, "module Services"
        assert_includes content, "module Auth"
        assert_includes content, "class TokenValidator"
      end

      def test_new_class_does_not_create_frozen_string_literal
        run_new_command("class", "MyGem::Authentication")
        content = File.read("lib/my_gem/authentication.rb")

        refute_includes content, "frozen_string_literal"
      end

      def test_new_class_with_constant_notation
        run_new_command("class", "MyGem::SomeNameSpace::NewClass")

        assert_path_exists "lib/my_gem/some_name_space/new_class.rb"
        content = File.read("lib/my_gem/some_name_space/new_class.rb")

        assert_includes content, "module MyGem"
        assert_includes content, "module SomeNameSpace"
        assert_includes content, "class NewClass"
      end

      # --- Test file generation ---

      def test_new_class_creates_minitest_file
        run_new_command("class", "MyGem::Authentication")

        assert_path_exists "test/my_gem/authentication_test.rb"
        content = File.read("test/my_gem/authentication_test.rb")

        assert_includes content, 'require "test_helper"'
        assert_includes content, "module MyGem"
        assert_includes content, "Minitest::Test"
      end

      def test_new_class_creates_rspec_file_when_spec_dir_exists
        FileUtils.rm_rf("test")
        FileUtils.mkdir_p("spec")
        run_new_command("class", "MyGem::Authentication")

        assert_path_exists "spec/my_gem/authentication_spec.rb"
        content = File.read("spec/my_gem/authentication_spec.rb")

        assert_includes content, 'require "spec_helper"'
        assert_includes content, "RSpec.describe MyGem::Authentication"
      end

      def test_new_class_creates_nested_test_file
        run_new_command("class", "MyGem::Services::Authentication")

        assert_path_exists "test/my_gem/services/authentication_test.rb"
      end

      # --- Module generation ---

      def test_new_module_creates_lib_file
        run_new_command("module", "MyGem::Middleware")

        assert_path_exists "lib/my_gem/middleware.rb"
        content = File.read("lib/my_gem/middleware.rb")

        assert_includes content, "module MyGem"
        assert_includes content, "module Middleware"
        refute_includes content, "class"
      end

      def test_new_module_does_not_create_test_file
        run_new_command("module", "MyGem::Middleware")

        refute_path_exists "test/my_gem/middleware_test.rb"
      end

      def test_new_module_with_nested_constant
        run_new_command("module", "MyGem::Services::Concerns")
        content = File.read("lib/my_gem/services/concerns.rb")

        assert_includes content, "module MyGem"
        assert_includes content, "module Services"
        assert_includes content, "module Concerns"
      end

      # --- Command generation ---

      def test_new_command_creates_command_file
        FileUtils.mkdir_p("lib/my_gem/cli/commands")
        run_new_command("command", "deploy")

        assert_path_exists "lib/my_gem/cli/commands/deploy.rb"

        content = File.read("lib/my_gem/cli/commands/deploy.rb")

        assert_includes content, "class Deploy < Command"
        assert_includes content, "module MyGem"
        assert_includes content, "module Commands"
        assert_includes content, "description"
      end

      def test_new_command_creates_minitest_file
        FileUtils.mkdir_p("lib/my_gem/cli/commands")
        run_new_command("command", "deploy")

        assert_path_exists "test/my_gem/cli/commands/deploy_test.rb"
        content = File.read("test/my_gem/cli/commands/deploy_test.rb")

        assert_includes content, 'require "test_helper"'
        assert_includes content, "Minitest::Test"
        assert_includes content, "Commands::Deploy"
      end

      def test_new_command_creates_rspec_file_when_spec_dir_exists
        FileUtils.rm_rf("test")
        FileUtils.mkdir_p("spec")
        FileUtils.mkdir_p("lib/my_gem/cli/commands")
        run_new_command("command", "deploy")

        assert_path_exists "spec/my_gem/cli/commands/deploy_spec.rb"
        content = File.read("spec/my_gem/cli/commands/deploy_spec.rb")

        assert_includes content, 'require "spec_helper"'
        assert_includes content, "RSpec.describe MyGem::CLI::Commands::Deploy"
      end

      # --- Error handling ---

      def test_new_fails_without_gemspec
        FileUtils.rm("my_gem.gemspec")
        stdout = StringIO.new
        command = Commands::New.new(stdout: stdout)

        exit_code = command.main(["class", "MyGem::Foo"])

        assert_equal 1, exit_code
      end

      def test_new_fails_with_unknown_type
        stdout = StringIO.new
        command = Commands::New.new(stdout: stdout)

        exit_code = command.main(["widget", "MyGem::Foo"])

        assert_equal 1, exit_code
      end

      def test_new_fails_with_wrong_gem_module
        stdout = StringIO.new
        command = Commands::New.new(stdout: stdout)

        exit_code = command.main(["class", "WrongGem::Foo"])

        assert_equal 1, exit_code
      end

      private

      def run_new_command(type, path)
        stdout = StringIO.new
        command = Commands::New.new(stdout: stdout)
        command.main([type, path])
      end
    end
  end
end
