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
        File.write("spec/spec_helper.rb", "")
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
        File.write("spec/spec_helper.rb", "")
        FileUtils.mkdir_p("lib/my_gem/cli/commands")
        run_new_command("command", "deploy")

        assert_path_exists "spec/my_gem/cli/commands/deploy_spec.rb"
        content = File.read("spec/my_gem/cli/commands/deploy_spec.rb")

        assert_includes content, 'require "spec_helper"'
        assert_includes content, "RSpec.describe MyGem::CLI::Commands::Deploy"
      end

      # --- CommandKit bootstrap ---

      def test_new_command_bootstraps_cli_router
        run_new_command("command", "deploy")
        content = File.read("lib/my_gem/cli.rb")

        assert_includes content, "class CLI"
        assert_includes content, "include CommandKit::Commands"
        assert_includes content, 'command_name "my_gem"'
        assert_includes content, "version MyGem::VERSION"
      end

      def test_new_command_bootstraps_base_command
        run_new_command("command", "deploy")
        content = File.read("lib/my_gem/cli/command.rb")

        assert_includes content, "class Command < CommandKit::Command"
        assert_includes content, "include CommandKit::Interactive"
      end

      def test_new_command_creates_executable_starting_the_cli
        run_new_command("command", "deploy")
        content = File.read("exe/my_gem")

        assert_predicate Pathname("exe/my_gem"), :executable?
        assert_includes content, 'require "my_gem/cli"'
        assert_includes content, "MyGem::CLI.start"
      end

      def test_new_command_makes_an_existing_executable_executable
        FileUtils.mkdir_p("exe")
        File.write("exe/my_gem", "#!/usr/bin/env ruby\nrequire \"my_gem/cli\"\nMyGem::CLI.start\n")
        run_new_command("command", "deploy")

        assert_predicate Pathname("exe/my_gem"), :executable?
        assert_equal "#!/usr/bin/env ruby\nrequire \"my_gem/cli\"\nMyGem::CLI.start\n", File.read("exe/my_gem")
      end

      def test_new_command_keeps_existing_cli_files
        FileUtils.mkdir_p("lib/my_gem/cli")
        File.write("lib/my_gem/cli.rb", "# custom router\n")
        File.write("lib/my_gem/cli/command.rb", "# custom base\n")
        run_new_command("command", "deploy")

        assert_equal "# custom router\n", File.read("lib/my_gem/cli.rb")
        assert_equal "# custom base\n", File.read("lib/my_gem/cli/command.rb")
      end

      def test_new_command_adds_command_kit_dependency_to_gemspec
        write_scaffolded_gem
        run_new_command("command", "deploy")
        gemspec = File.read("my_gem.gemspec")

        assert_includes gemspec, 'spec.add_dependency "command_kit"'
        assert_operator gemspec.index("command_kit"), :<, gemspec.index('"zeitwerk"')
      end

      def test_new_command_does_not_duplicate_command_kit_dependency
        write_scaffolded_gem
        run_new_command("command", "deploy")
        run_new_command("command", "status")

        assert_equal 1, File.read("my_gem.gemspec").scan("command_kit").size
      end

      def test_new_command_inflects_cli_in_the_loader
        write_scaffolded_gem
        run_new_command("command", "deploy")

        expected = <<~RUBY
          module MyGem
            LOADER = Zeitwerk::Loader.for_gem.tap do |l|
              l.inflector.inflect("cli" => "CLI")
              l.setup
            end
          end
        RUBY

        assert_includes File.read("lib/my_gem.rb"), expected
      end

      def test_new_command_inflects_cli_only_once
        write_scaffolded_gem
        run_new_command("command", "deploy")
        run_new_command("command", "status")

        assert_equal 1, File.read("lib/my_gem.rb").scan("inflect(").size
      end

      def test_new_command_bundles_when_the_dependency_was_added
        write_scaffolded_gem
        File.write("Gemfile", "source \"https://rubygems.org\"\ngemspec\n")
        sh_calls = run_new_command_recording_sh("command", "deploy")

        assert_includes sh_calls, ["bundle", "install"]
      end

      def test_new_command_does_not_bundle_when_the_dependency_was_present
        write_scaffolded_gem
        File.write("Gemfile", "source \"https://rubygems.org\"\ngemspec\n")
        run_new_command("command", "deploy")
        sh_calls = run_new_command_recording_sh("command", "status")

        assert_empty sh_calls
      end

      def test_new_command_in_hyphenated_gem_targets_the_nested_module
        FileUtils.rm("my_gem.gemspec")
        FileUtils.rm_rf("lib/my_gem")
        File.write("my-gem.gemspec", 'Gem::Specification.new { |s| s.name = "my-gem" }')
        FileUtils.mkdir_p("lib/my/gem")
        run_new_command("command", "deploy")

        assert_includes File.read("exe/my-gem"), 'require "my/gem/cli"'
        assert_includes File.read("exe/my-gem"), "My::Gem::CLI.start"
        assert_includes File.read("lib/my/gem/cli.rb"), "module My::Gem"
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

      def test_new_roots_foreign_namespace_under_gem_module
        # Bare or foreign-root constants are auto-prefixed with the gem module
        # rather than rejected; WrongGem::Foo becomes MyGem::WrongGem::Foo.
        run_new_command("class", "WrongGem::Foo")

        assert_path_exists "lib/my_gem/wrong_gem/foo.rb"
      end

      private

      def run_new_command(type, path)
        stdout = StringIO.new
        command = Commands::New.new(stdout: stdout)
        command.main([type, path])
      end

      def run_new_command_recording_sh(type, path)
        sh_calls = []
        command = Commands::New.new(stdout: StringIO.new)
        command.define_singleton_method(:sh) { |*args| sh_calls << args }
        command.main([type, path])
        sh_calls
      end

      def write_scaffolded_gem
        File.write("lib/my_gem.rb", <<~RUBY)
          require "zeitwerk"

          module MyGem
            LOADER = Zeitwerk::Loader.for_gem.tap(&:setup)
          end
        RUBY
        File.write("my_gem.gemspec", <<~RUBY)
          Gem::Specification.new do |spec|
            spec.name = "my_gem"
            spec.add_dependency "zeitwerk"
          end
        RUBY
      end
    end
  end
end
