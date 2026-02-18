require "test_helper"
require "gempilot/cli"
require "tmpdir"
require "stringio"

module Gempilot
  class CLI
    class CreateCommandTest < Minitest::Test
      def setup
        @tmpdir = Dir.mktmpdir("create_command_test")
        @original_dir = Dir.pwd
        Dir.chdir(@tmpdir)
      end

      def teardown
        Dir.chdir(@original_dir)
        FileUtils.rm_rf(@tmpdir)
      end

      def test_creates_gem_directory_structure
        run_create_command("test_gem")

        assert File.directory?("test_gem")
        assert File.directory?("test_gem/lib")
        assert File.directory?("test_gem/lib/test_gem")
        assert File.directory?("test_gem/test")
        assert File.directory?("test_gem/bin")
      end

      def test_creates_gemspec
        run_create_command("test_gem")

        gemspec = File.read("test_gem/test_gem.gemspec")

        assert_includes gemspec, 'spec.name = "test_gem"'
        assert_includes gemspec, "TestGem::VERSION"
        assert_includes gemspec, '"Test Author"'
        assert_includes gemspec, '"test@example.com"'
        assert_includes gemspec, '"A test gem"'
        refute_includes gemspec, "TODO"
      end

      def test_creates_lib_with_zeitwerk
        run_create_command("test_gem")

        main_rb = File.read("test_gem/lib/test_gem.rb")

        assert_includes main_rb, 'require "zeitwerk"'
        assert_includes main_rb, "LOADER = Zeitwerk::Loader.for_gem"
        assert_includes main_rb, "LOADER.setup"
        assert_includes main_rb, "module TestGem"
      end

      def test_creates_version_file
        run_create_command("test_gem")

        version_rb = File.read("test_gem/lib/test_gem/version.rb")

        assert_includes version_rb, "module TestGem"
        assert_includes version_rb, 'VERSION = "0.0.1"'
      end

      def test_creates_test_helper
        run_create_command("test_gem")

        test_helper = File.read("test_gem/test/test_helper.rb")

        assert_includes test_helper, "minitest/autorun"
        assert_includes test_helper, "minitest/reporters"
        assert_includes test_helper, 'require "test_gem"'
      end

      def test_creates_test_file
        run_create_command("test_gem")

        test_file = File.read("test_gem/test/test_gem_test.rb")

        assert_includes test_file, "class TestGemTest < Minitest::Test"
        assert_includes test_file, "TestGem::VERSION"
      end

      def test_bin_scripts_are_executable
        run_create_command("test_gem")

        assert File.executable?("test_gem/bin/console")
        assert File.executable?("test_gem/bin/setup")
      end

      def test_creates_config_files
        run_create_command("test_gem")

        assert_path_exists "test_gem/.rubocop.yml"
        assert_path_exists "test_gem/.gitignore"
        assert_path_exists "test_gem/.ruby-version"
      end

      def test_exe_flag_creates_executable
        run_create_command("test_gem", "--exe")

        assert File.directory?("test_gem/exe")
        assert_path_exists "test_gem/exe/test_gem"
        assert File.executable?("test_gem/exe/test_gem")
      end

      def test_inflects_module_name_correctly
        run_create_command("my_cool_gem")

        version_rb = File.read("my_cool_gem/lib/my_cool_gem/version.rb")

        assert_includes version_rb, "module MyCoolGem"
      end

      def test_rubocop_yml_is_valid_yaml
        run_create_command("test_gem")

        content = File.read("test_gem/.rubocop.yml")

        refute_includes content, "<%"
        assert_includes content, "rubocop-minitest"
      end

      # RSpec support tests

      def test_rspec_creates_spec_directory
        run_create_command("test_gem", "--test", "rspec")

        assert File.directory?("test_gem/spec")
        refute File.directory?("test_gem/test")
      end

      def test_rspec_creates_spec_files
        run_create_command("test_gem", "--test", "rspec")

        assert_path_exists "test_gem/spec/spec_helper.rb"
        assert_path_exists "test_gem/spec/test_gem_spec.rb"
        assert_path_exists "test_gem/.rspec"
      end

      def test_rspec_spec_helper_content
        run_create_command("test_gem", "--test", "rspec")

        helper = File.read("test_gem/spec/spec_helper.rb")

        assert_includes helper, 'require "test_gem"'
        assert_includes helper, "RSpec.configure"
        assert_includes helper, "disable_monkey_patching!"
      end

      def test_rspec_spec_file_content
        run_create_command("test_gem", "--test", "rspec")

        spec_file = File.read("test_gem/spec/test_gem_spec.rb")

        assert_includes spec_file, "RSpec.describe TestGem"
        assert_includes spec_file, "TestGem::VERSION"
      end

      def test_rspec_gemfile_has_rspec_gem
        run_create_command("test_gem", "--test", "rspec")

        gemfile = File.read("test_gem/Gemfile")

        assert_includes gemfile, 'gem "rspec"'
        refute_includes gemfile, 'gem "minitest"'
      end

      def test_rspec_rakefile_has_rspec_task
        run_create_command("test_gem", "--test", "rspec")

        rakefile = File.read("test_gem/Rakefile")

        assert_includes rakefile, "rspec/core/rake_task"
        assert_includes rakefile, ":spec"
        refute_includes rakefile, "minitest"
      end

      def test_git_branch_flag_passes_branch_to_git_init
        sh_calls = []
        stdout = StringIO.new
        args = [
          "--author", "Test Author",
          "--email", "test@example.com",
          "--summary", "A test gem",
          "--ruby-version", "3.4.8",
          "--test", "minitest",
          "--no-exe",
          "--git",
          "--branch", "develop",
          "test_gem"
        ]

        command = Commands::Create.new(stdout: stdout)
        command.define_singleton_method(:sh) do |cmd, *arguments|
          sh_calls << [cmd, *arguments]
        end
        command.main(args)

        git_init_call = sh_calls.find { |call| call[0] == "git" && call[1] == "init" }

        assert git_init_call, "Expected a 'git init' call"
        assert_includes git_init_call, "-b"
        assert_includes git_init_call, "develop"
      end

      def test_sh_runs_inside_unbundled_env
        system_calls = []
        stdout = StringIO.new
        args = [
          "--author", "Test Author",
          "--email", "test@example.com",
          "--summary", "A test gem",
          "--ruby-version", "3.4.8",
          "--test", "minitest",
          "--no-exe",
          "--no-git",
          "test_gem"
        ]

        command = Commands::Create.new(stdout: stdout)
        # Stub system (not sh) so the real sh method runs with Bundler.with_unbundled_env
        command.define_singleton_method(:system) do |cmd, *arguments|
          system_calls << {
            command: [cmd, *arguments],
            bundle_gemfile: ENV["BUNDLE_GEMFILE"]
          }
          true
        end
        command.main(args)

        bundle_call = system_calls.find { |c| c[:command].first == "bundle" }
        assert bundle_call, "Expected a 'bundle' system call"
        assert_nil bundle_call[:bundle_gemfile],
          "bundle install should run without BUNDLE_GEMFILE set (inside Bundler.with_unbundled_env)"
      end

      def test_generated_files_have_no_leading_blank_lines
        run_create_command("test_gem")

        files = [
          "test_gem/lib/test_gem.rb",
          "test_gem/lib/test_gem/version.rb",
          "test_gem/test/test_helper.rb",
          "test_gem/test/test_gem_test.rb",
          "test_gem/test_gem.gemspec"
        ]

        files.each do |path|
          content = File.read(path)
          refute content.start_with?("\n"),
            "#{path} should not start with a blank line"
        end
      end

      def test_gemfile_gems_are_alphabetically_ordered
        run_create_command("test_gem")

        gemfile = File.read("test_gem/Gemfile")
        gem_lines = gemfile.lines.select { |l| l.start_with?('gem "') }
        gem_names = gem_lines.map { |l| l[/gem "([^"]+)"/, 1] }

        assert_equal gem_names.sort, gem_names,
          "Gems in Gemfile should be in alphabetical order"
      end

      def test_version_constant_is_frozen
        run_create_command("test_gem")

        version_rb = File.read("test_gem/lib/test_gem/version.rb")

        assert_includes version_rb, '.freeze',
          "VERSION constant should be frozen"
      end

      def test_rubocop_yml_uses_correct_namespaces
        run_create_command("test_gem")

        content = File.read("test_gem/.rubocop.yml")

        refute_includes content, "Style/RedundantLineBreak",
          "Should use Layout/RedundantLineBreak, not Style/RedundantLineBreak"
      end

      def test_rspec_generated_files_have_no_leading_blank_lines
        run_create_command("test_gem", "--test", "rspec")

        files = [
          "test_gem/lib/test_gem.rb",
          "test_gem/test_gem.gemspec"
        ]

        files.each do |path|
          content = File.read(path)
          refute content.start_with?("\n"),
            "#{path} should not start with a blank line"
        end
      end

      def test_rspec_gemfile_gems_are_alphabetically_ordered
        run_create_command("test_gem", "--test", "rspec")

        gemfile = File.read("test_gem/Gemfile")
        gem_lines = gemfile.lines.select { |l| l.start_with?('gem "') }
        gem_names = gem_lines.map { |l| l[/gem "([^"]+)"/, 1] }

        assert_equal gem_names.sort, gem_names,
          "Gems in Gemfile should be in alphabetical order"
      end

      def test_rspec_rubocop_has_rspec_plugin
        run_create_command("test_gem", "--test", "rspec")

        rubocop = File.read("test_gem/.rubocop.yml")

        assert_includes rubocop, "rubocop-rspec"
        refute_includes rubocop, "rubocop-minitest"
      end

      # Zeitwerk validation tests

      def test_creates_zeitwerk_test_file
        run_create_command("test_gem")

        assert_path_exists "test_gem/test/zeitwerk_test.rb"

        content = File.read("test_gem/test/zeitwerk_test.rb")

        assert_includes content, "class ZeitwerkTest < Minitest::Test"
        assert_includes content, "TestGem::LOADER.eager_load(force: true)"
      end

      def test_rspec_creates_zeitwerk_spec_file
        run_create_command("test_gem", "--test", "rspec")

        assert_path_exists "test_gem/spec/zeitwerk_spec.rb"

        content = File.read("test_gem/spec/zeitwerk_spec.rb")

        assert_includes content, 'RSpec.describe "Zeitwerk"'
        assert_includes content, "TestGem::LOADER.eager_load(force: true)"
      end

      def test_rakefile_includes_zeitwerk_validate_task
        run_create_command("test_gem")

        rakefile = File.read("test_gem/Rakefile")

        assert_includes rakefile, "namespace :zeitwerk"
        assert_includes rakefile, "eager_load"
      end

      # Gemspec tests

      def test_gemspec_uses_git_ls_files
        run_create_command("test_gem")

        gemspec = File.read("test_gem/test_gem.gemspec")

        assert_includes gemspec, "git"
        assert_includes gemspec, "ls-files"
        assert_includes gemspec, "IO.popen"
      end

      def test_gemspec_has_glob_fallback
        run_create_command("test_gem")

        gemspec = File.read("test_gem/test_gem.gemspec")

        assert_includes gemspec, "Dir.glob"
        assert_includes gemspec, "files.empty?"
      end

      # CI workflow tests

      def test_creates_ci_workflow
        run_create_command("test_gem")

        assert_path_exists "test_gem/.github/workflows/ci.yml"
      end

      def test_ci_workflow_has_test_step
        run_create_command("test_gem")

        ci = File.read("test_gem/.github/workflows/ci.yml")

        assert_includes ci, "bundle exec rake test"
        assert_includes ci, "bundle exec rake rubocop"
      end

      def test_rspec_ci_workflow_has_spec_step
        run_create_command("test_gem", "--test", "rspec")

        ci = File.read("test_gem/.github/workflows/ci.yml")

        assert_includes ci, "bundle exec rake spec"
        refute_includes ci, "bundle exec rake test"
      end

      # Version rake task tests

      def test_creates_rakelib_directory
        run_create_command("test_gem")
        assert File.directory?("test_gem/rakelib")
      end

      def test_creates_version_rake_task
        run_create_command("test_gem")
        assert_path_exists "test_gem/rakelib/version.rake"
      end

      def test_version_rake_has_bump_task
        run_create_command("test_gem")
        content = File.read("test_gem/rakelib/version.rake")
        assert_includes content, "task :bump"
      end

      def test_version_rake_has_correct_module_name
        run_create_command("test_gem")
        content = File.read("test_gem/rakelib/version.rake")
        assert_includes content, "TestGem::VERSION"
      end

      def test_version_rake_has_no_monkey_patches
        run_create_command("test_gem")
        content = File.read("test_gem/rakelib/version.rake")
        refute_includes content, "class String"
      end

      def test_version_rake_uses_file_locking
        run_create_command("test_gem")
        content = File.read("test_gem/rakelib/version.rake")
        assert_includes content, "flock"
      end

      # Git config defaults

      def test_git_config_defaults_do_not_crash_without_git_config
        # Simulate no git config available (no global config, no repo)
        gem_root = File.expand_path("../../..", __dir__)
        env = {
          "HOME" => "/nonexistent",
          "GIT_CONFIG_NOSYSTEM" => "1",
          "GIT_CONFIG_GLOBAL" => "/nonexistent",
          "BUNDLE_GEMFILE" => File.join(gem_root, "Gemfile")
        }

        script = <<~RUBY
          require "bundler/setup"
          require "stringio"
          require "gempilot/cli"
          cmd = Gempilot::CLI::Commands::Create.new(stdout: StringIO.new)
          puts cmd.options[:author].inspect
          puts cmd.options[:email].inspect
        RUBY

        output = IO.popen(env, [RbConfig.ruby, "-e", script], chdir: @tmpdir, err: "/dev/null") { |io| io.read }

        assert_equal 0, $?.exitstatus, "Create command should not crash when git config unavailable"
        # Defaults should resolve to empty strings, not nil or error messages
        lines = output.lines.map(&:strip)
        assert_includes ["\"\"", "nil"], lines[0],
          "Author default should be empty string or nil when git config unavailable"
      end

      # Integration: generated gem's default rake task passes

      def test_generated_gem_default_rake_task_passes
        stdout = StringIO.new
        args = [
          "--author", "Test Author",
          "--email", "test@example.com",
          "--summary", "A test gem",
          "--ruby-version", RUBY_VERSION,
          "--test", "minitest",
          "--no-exe",
          "--no-git",
          "test_gem"
        ]

        command = Commands::Create.new(stdout: stdout)
        command.main(args)

        Dir.chdir("test_gem") do
          Bundler.with_unbundled_env do
            output = `bundle exec rake 2>&1`
            assert_equal 0, $?.exitstatus, "Default rake task failed in generated gem:\n#{output}"
          end
        end
      end

      private

      def run_create_command(gem_name, *extra_args)
        stdout = StringIO.new
        args = [
          "--author", "Test Author",
          "--email", "test@example.com",
          "--summary", "A test gem",
          "--ruby-version", "3.4.8",
          "--test", "minitest",
          "--no-exe",
          "--no-git",
          *extra_args,
          gem_name
        ]

        command = Commands::Create.new(stdout: stdout)
        # Stub bundle install to avoid network calls in tests
        command.define_singleton_method(:sh) do |cmd, *arguments|
          # Skip actual shell commands in tests
        end
        command.main(args)
      end
    end
  end
end
