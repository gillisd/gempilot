require "rake"
require "rake/tasklib"
require_relative "project"
require_relative "version_tag"
require_relative "github_release"

module Gempilot
  ## Rake tasks for version lifecycle management.
  class VersionTask < Rake::TaskLib
    attr_reader :project

    def initialize(root: Dir.pwd)
      super()
      @project = Project.new(root)
      define_tasks
    end

    private

    def define_tasks
      define_version_tasks
      define_version_composite_tasks
      define_github_tasks
    end

    def define_version_tasks
      project = @project

      namespace :version do
        define_current_task(project)
        define_bump_task(project)
        define_commit_task(project)
        define_tag_task(project)
        define_untag_task(project)
        define_reset_task(project)
        define_revert_task(project)
      end
    end

    def define_version_composite_tasks
      desc "Bump version, commit, and tag (rake version:release[minor])"
      task "version:release", [:segment] => ["version:bump", "version:commit", "version:tag"]

      desc "Untag and reset version"
      task "version:unrelease" => ["version:untag", "version:reset"]
    end

    def define_current_task(project)
      desc "Display the current version"
      task(:current) { puts "Current version: #{project.version_value}" }
    end

    def define_bump_task(project)
      desc "Bump version (patch default, or rake version:bump[minor])"
      task :bump, [:segment] do |_t, args|
        segment = (args[:segment] || :patch).to_sym
        old_version = project.version
        new_version = old_version.bump(segment)
        project.write_version!(old_version, new_version)
        project.refresh_version!
        puts "Version bumped from #{old_version.value} to #{project.version_value}"
      end
    end

    def define_commit_task(project)
      desc "Commit the version change"
      task(:commit) { VersionTag.new(project.version).create }
    end

    def define_tag_task(project)
      desc "Tag the current version"
      task(:tag) { VersionTag.new(project.version).tag }
    end

    def define_untag_task(project)
      desc "Untag the current version"
      task(:untag) { VersionTag.new(project.version).untag }
    end

    def define_reset_task(project)
      desc "Reset the last version bump commit"
      task :reset do
        VersionTag.new(project.version).reset
        project.refresh_version!
      end
    end

    def define_revert_task(project)
      desc "Revert the last version bump commit"
      task :revert do
        VersionTag.new(project.version).revert
        project.refresh_version!
      end
    end

    def define_github_tasks
      project = @project

      namespace "version:github" do
        desc "Create a GitHub release for the current version"
        task(:release) { GithubRelease.new(project.version_tag).create }

        desc "Delete the GitHub release for the current version"
        task(:unrelease) { GithubRelease.new(project.version_tag).destroy }

        desc "List GitHub releases"
        task(:list) { GithubRelease.new(project.version_tag).list }
      end
    end
  end
end
