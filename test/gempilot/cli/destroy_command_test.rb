require "test_helper"
require "gempilot/cli"
require "tmpdir"
require "stringio"

module Gempilot
  class CLI
    class DestroyCommandTest < Minitest::Test
      def setup
        @tmpdir = Dir.mktmpdir("destroy_command_test")
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

      # --- Class destruction ---

      def test_destroy_class_removes_lib_file
        create_class_file("lib/my_gem/authentication.rb")
        run_destroy_command("class", "MyGem::Authentication")
        refute_path_exists "lib/my_gem/authentication.rb"
      end

      def test_destroy_class_removes_test_file
        create_class_file("lib/my_gem/authentication.rb")
        create_test_file("test/my_gem/authentication_test.rb")
        run_destroy_command("class", "MyGem::Authentication")
        refute_path_exists "test/my_gem/authentication_test.rb"
      end

      def test_destroy_class_removes_empty_parent_dirs
        FileUtils.mkdir_p("lib/my_gem/services")
        create_class_file("lib/my_gem/services/authentication.rb")
        FileUtils.mkdir_p("test/my_gem/services")
        create_test_file("test/my_gem/services/authentication_test.rb")

        run_destroy_command("class", "MyGem::Services::Authentication")

        refute_path_exists "lib/my_gem/services/authentication.rb"
        refute File.directory?("lib/my_gem/services"),
          "Empty parent directory lib/my_gem/services should be removed"
        refute_path_exists "test/my_gem/services/authentication_test.rb"
        refute File.directory?("test/my_gem/services"),
          "Empty parent directory test/my_gem/services should be removed"
      end

      def test_destroy_class_preserves_non_empty_parent_dirs
        FileUtils.mkdir_p("lib/my_gem/services")
        create_class_file("lib/my_gem/services/authentication.rb")
        create_class_file("lib/my_gem/services/authorization.rb")

        run_destroy_command("class", "MyGem::Services::Authentication")

        refute_path_exists "lib/my_gem/services/authentication.rb"
        assert File.directory?("lib/my_gem/services"),
          "Non-empty parent directory should be preserved"
        assert_path_exists "lib/my_gem/services/authorization.rb"
      end

      def test_destroy_class_skips_missing_file
        stdout = StringIO.new
        command = Commands::Destroy.new(stdout: stdout)
        exit_code = command.main(["class", "MyGem::NonExistent"])

        assert_equal 0, exit_code
      end

      def test_destroy_class_removes_rspec_spec_file
        FileUtils.rm_rf("test")
        FileUtils.mkdir_p("spec/my_gem")
        create_class_file("lib/my_gem/authentication.rb")
        File.write("spec/my_gem/authentication_spec.rb", "# spec")

        run_destroy_command("class", "MyGem::Authentication")

        refute_path_exists "lib/my_gem/authentication.rb"
        refute_path_exists "spec/my_gem/authentication_spec.rb"
      end

      # --- Module destruction ---

      def test_destroy_module_removes_lib_file
        create_class_file("lib/my_gem/middleware.rb")
        run_destroy_command("module", "MyGem::Middleware")
        refute_path_exists "lib/my_gem/middleware.rb"
      end

      def test_destroy_module_does_not_touch_test_dir
        create_class_file("lib/my_gem/middleware.rb")
        FileUtils.mkdir_p("test/my_gem")
        File.write("test/my_gem/something_test.rb", "# test")

        run_destroy_command("module", "MyGem::Middleware")

        assert_path_exists "test/my_gem/something_test.rb"
      end

      # --- Command destruction ---

      def test_destroy_command_removes_command_file
        FileUtils.mkdir_p("lib/my_gem/cli/commands")
        File.write("lib/my_gem/cli/commands/deploy.rb", "# command")

        run_destroy_command("command", "deploy")

        refute_path_exists "lib/my_gem/cli/commands/deploy.rb"
      end

      def test_destroy_command_removes_test_file
        FileUtils.mkdir_p("lib/my_gem/cli/commands")
        File.write("lib/my_gem/cli/commands/deploy.rb", "# command")
        FileUtils.mkdir_p("test/my_gem/cli/commands")
        File.write("test/my_gem/cli/commands/deploy_test.rb", "# test")

        run_destroy_command("command", "deploy")

        refute_path_exists "lib/my_gem/cli/commands/deploy.rb"
        refute_path_exists "test/my_gem/cli/commands/deploy_test.rb"
      end

      def test_destroy_command_removes_rspec_test_file
        FileUtils.rm_rf("test")
        FileUtils.mkdir_p("spec")
        FileUtils.mkdir_p("lib/my_gem/cli/commands")
        File.write("lib/my_gem/cli/commands/deploy.rb", "# command")
        FileUtils.mkdir_p("spec/my_gem/cli/commands")
        File.write("spec/my_gem/cli/commands/deploy_spec.rb", "# spec")

        run_destroy_command("command", "deploy")

        refute_path_exists "lib/my_gem/cli/commands/deploy.rb"
        refute_path_exists "spec/my_gem/cli/commands/deploy_spec.rb"
      end

      # --- Error handling ---

      def test_destroy_fails_without_gemspec
        FileUtils.rm("my_gem.gemspec")
        stdout = StringIO.new
        command = Commands::Destroy.new(stdout: stdout)

        exit_code = command.main(["class", "MyGem::Foo"])

        assert_equal 1, exit_code
      end

      def test_destroy_fails_with_unknown_type
        stdout = StringIO.new
        command = Commands::Destroy.new(stdout: stdout)

        exit_code = command.main(["widget", "MyGem::Foo"])

        assert_equal 1, exit_code
      end

      def test_destroy_fails_with_wrong_gem_module
        stdout = StringIO.new
        command = Commands::Destroy.new(stdout: stdout)

        exit_code = command.main(["class", "WrongGem::Foo"])

        assert_equal 1, exit_code
      end

      private

      def run_destroy_command(type, path)
        stdout = StringIO.new
        command = Commands::Destroy.new(stdout: stdout)
        command.main([type, path])
      end

      def create_class_file(path)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, "# placeholder\n")
      end

      def create_test_file(path)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, "# test placeholder\n")
      end
    end
  end
end
