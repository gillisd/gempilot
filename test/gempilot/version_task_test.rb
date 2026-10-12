require "test_helper"
require "rake"
require "tmpdir"

module Gempilot
  class VersionTaskTest < Minitest::Test
    def setup
      @root = Pathname(Dir.mktmpdir("version_task_test"))
      @original_application = Rake.application
      Rake.application = Rake::Application.new
    end

    def teardown
      Rake.application = @original_application
      FileUtils.rm_rf(@root)
    end

    def test_ambiguous_project_raises_without_project_name
      write_gem "ambiguous_alpha", "AmbiguousAlpha", "1.0.0"
      write_gem "ambiguous_beta", "AmbiguousBeta", "2.0.0"

      task = VersionTask.new(root: @root)

      assert_raises(Project::ProjectIntrospectionError) { task.project.version }
    end

    def test_project_name_selects_among_ambiguous_projects
      write_gem "chosen_alpha", "ChosenAlpha", "1.0.0"
      write_gem "chosen_beta", "ChosenBeta", "2.0.0"

      task = VersionTask.new(root: @root, project_name: "chosen_beta")

      assert_equal "2.0.0", task.project.version_value
    end

    def test_project_name_resolves_extension_gem
      write_gem "host_gem", "HostGem", "1.0.0"
      write_gem "host_gem/extension", "HostGem::Extension", "3.1.4"

      task = VersionTask.new(root: @root, project_name: "host_gem-extension")

      assert_equal "host_gem-extension", task.project.name
      assert_equal "3.1.4", task.project.version_value
    end

    def test_project_name_drives_version_current_task
      write_gem "current_alpha", "CurrentAlpha", "1.0.0"
      write_gem "current_beta", "CurrentBeta", "2.0.0"
      VersionTask.new(root: @root, project_name: "current_alpha")

      assert_output("Current version: 1.0.0\n") { Rake::Task["version:current"].invoke }
    end

    def test_unknown_project_name_raises
      write_gem "known_gem", "KnownGem", "1.0.0"

      task = VersionTask.new(root: @root, project_name: "unknown_gem")

      error = assert_raises(Project::ProjectIntrospectionError) { task.project.version }
      assert_match "lib/unknown_gem", error.message
    end

    private

    def write_gem(require_path, module_name, version)
      lib_project = @root.join("lib", require_path)
      lib_project.mkpath
      lib_project.sub_ext(".rb").write("")
      namespaces = module_name.split("::")
      opening = namespaces.map { "module #{it}; " }.join
      closing = " end" * namespaces.size
      lib_project.join("version.rb").write(%(#{opening}VERSION = "#{version}".freeze;#{closing}\n))
    end
  end
end
