require "open3"

module Gempilot
  ## Manages git operations for version releases.
  class VersionTag
    include StrictShell

    attr_reader :version

    def initialize(version)
      @version = version
    end

    def create
      _, _, status = Open3.capture3("git", "diff", "--staged", "--quiet")
      raise "Cannot proceed, staging area must be clean" unless status.success?

      sh "git", "add", version.path.to_s
      sh "git", "commit", "-m", "Bump version to #{version.value}"
    end

    def tag
      assert_last_commit_is_bump!
      sh "git", "tag", version.tag
    end

    def untag
      assert_last_commit_is_bump!
      sh "git", "tag", "--delete", version.tag
    end

    def reset
      assert_last_commit_is_bump!
      sh "git", "reset", "--quiet", "--mixed", "HEAD~1"
      sh "git", "restore", version.path.to_s
    end

    def revert
      assert_last_commit_is_bump!
      sh "git", "revert", "HEAD", "--no-edit"
    end

    private

    def assert_last_commit_is_bump!
      message, status = Open3.capture2("git", "log", "-1", "--pretty=%B")
      raise "Failed to read last commit message" unless status.success?

      message.strip!
      raise "Last commit does not appear to be a version bump." unless message.start_with?("Bump version to ")
    end
  end
end
