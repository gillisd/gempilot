require_relative "project"
require_relative "version_tag"
require_relative "github_release"

root_path = File.expand_path("../", __dir__)
project = Project.new(root_path)

namespace :version do
  desc "Display the current version"
  task(:current) { puts "Current version: #{project.version_value}" }

  desc "Bump the patch version"
  task :bump do
    old_version = project.version
    new_version = project.increment_version
    project.write_version!(old_version, new_version)
    project.refresh_version!
    puts "Version bumped from #{old_version.value} to #{project.version_value}"
  end

  desc "Commit the version change"
  task(:commit) { VersionTag.new(project.version).create }

  desc "Tag the current version"
  task(:tag) { VersionTag.new(project.version).tag }

  desc "Untag the current version"
  task(:untag) { VersionTag.new(project.version).untag }

  desc "Reset the last version bump commit"
  task :reset do
    VersionTag.new(project.version).reset
    project.refresh_version!
  end

  desc "Revert the last version bump commit"
  task :revert do
    VersionTag.new(project.version).revert
    project.refresh_version!
  end

  desc "Bump version, commit, and tag"
  task release: ["version:bump", "version:commit", "version:tag"]

  desc "Untag and reset version"
  task unrelease: ["version:untag", "version:reset"]

  namespace :github do
    desc "Create a GitHub release for the current version"
    task(:release) { GithubRelease.new(project.version_tag).create }

    desc "Delete the GitHub release for the current version"
    task(:unrelease) { GithubRelease.new(project.version_tag).destroy }

    desc "List GitHub releases"
    task(:list) { GithubRelease.new(project.version_tag).list }
  end
end
