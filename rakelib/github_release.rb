require_relative "strict_shell"

# Manages GitHub releases for a version tag: creating releases
# with auto-generated notes, deleting releases, and listing them.
class GithubRelease
  include StrictShell

  attr_reader :tag

  def initialize(tag)
    @tag = tag
  end

  def create
    sh "git", "push"
    sh "git", "push", "--tags"
    sh "gh", "release", "create",
       "--generate-notes", "--fail-on-no-commits",
       tag
  end

  def destroy
    sh "gh", "release", "delete",
       "--yes", "--cleanup-tag",
       tag
  end

  def list
    sh "gh", "release", "list"
  end
end
