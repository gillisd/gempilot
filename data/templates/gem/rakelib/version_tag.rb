require "open3"
require_relative "strict_shell"

##
# Manages git operations for a version release: committing the version
# file change, tagging, untagging, resetting, and reverting.
class VersionTag
  include StrictShell

  attr_reader :version

  def initialize(version)
    @version = version
  end

  ##
  # Stages the version file and commits it with a "Bump version to" message.
  # Raises if the staging area is not clean before staging.
  def create
    _, _, status = Open3.capture3("git", "diff", "--staged", "--quiet")
    raise "Cannot proceed, staging area must be clean" unless status.success?

    sh "git", "add", version.path.to_s
    sh "git", "commit", "-m", "Bump version to #{version.value}"
  end

  ##
  # Creates a git tag for the current version at HEAD.
  def tag
    assert_last_commit_is_bump!
    sh "git", "tag", version.tag
  end

  ##
  # Deletes the git tag for the current version.
  def untag
    assert_last_commit_is_bump!
    sh "git", "tag", "--delete", version.tag
  end

  ##
  # Resets HEAD~1, undoing the version bump commit without reverting in history.
  def reset
    assert_last_commit_is_bump!
    sh "git", "reset", "--quiet", "--mixed", "HEAD~1"
    sh "git", "restore", version.path.to_s
  end

  ##
  # Creates a revert commit that undoes the version bump.
  def revert
    assert_last_commit_is_bump!
    sh "git", "revert", "HEAD", "--no-edit"
  end

  private

  def assert_last_commit_is_bump!
    message, status = Open3.capture2("git", "log", "-1", "--pretty=%B")
    raise "Failed to read last commit message" unless status.success?

    message.strip!
    abort "Last commit does not appear to be a version bump." unless message.start_with?("Bump version to ")
  end
end
