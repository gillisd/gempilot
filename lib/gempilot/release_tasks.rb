module Gempilot
  ## Rake task definitions for publishing a release to RubyGems and GitHub.
  ## Mixed into VersionTask. Assumes +bundler/gem_tasks+ has been required so the
  ## +build+, +release:guard_clean+, and +release:rubygem_push+ tasks exist (the
  ## generated Rakefile guarantees this). Fixes GitHub releasing by replacing
  ## bundler's +already_tagged?+-guarded +release:source_control_push+ with an
  ## idempotent push.
  module ReleaseTasks
    private

    def define_release_tasks(project)
      override_source_control_push(project)
      define_release_namespace(project)
      define_root_release_task
      define_unrelease_tasks(project)
    end

    def override_source_control_push(project)
      clear_task "release:source_control_push"
      task("release:source_control_push") { Origin.new(project.version_tag).push }
    end

    def define_release_namespace(project)
      namespace :release do
        define_rubygems_release
        define_github_release(project)
        define_release_list(project)
      end
    end

    def define_rubygems_release
      desc "Release the current version to RubyGems"
      task rubygems: %w[build release:guard_clean release:source_control_push release:rubygem_push]
    end

    def define_github_release(project)
      desc "Create a GitHub release for the current version"
      task github: "release:source_control_push" do
        GithubRelease.new(project.version_tag).create
      end
    end

    def define_release_list(project)
      namespace :list do
        desc "List GitHub releases"
        task(:github) { GithubRelease.new(project.version_tag).list }
      end
    end

    def define_root_release_task
      clear_task "release"
      desc "Release the current version to all remotes"
      task release: %w[release:rubygems release:github]
    end

    def define_unrelease_tasks(project)
      desc "Delete the current release from all remotes that support it"
      task unrelease: %w[unrelease:github]
      define_unrelease_namespace(project)
    end

    def define_unrelease_namespace(project)
      namespace :unrelease do
        desc "Delete the GitHub release for the current version"
        task(:github) { GithubRelease.new(project.version_tag).destroy }
      end
    end

    def clear_task(name)
      Rake::Task[name].clear if Rake::Task.task_defined?(name)
    end
  end
end
