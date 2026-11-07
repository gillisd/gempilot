module Gempilot
  ## Manages git operations for version releases.
  class VersionTag
    ## Commit-message prefix written for a version bump; the guard below
    ## matches on it, so the two must stay in sync.
    BUMP_MESSAGE_PREFIX = "Bump version to ".freeze

    attr_reader :version

    def initialize(version)
      @version = version
    end

    def create
      staging_clean = Shell.capture("git", "diff", "--staged", "--quiet").success?
      raise "Cannot proceed, staging area must be clean" unless staging_clean

      Shell.run("git", "add", version.path.to_s)
      Shell.run("git", "commit", "-m", "#{BUMP_MESSAGE_PREFIX}#{version.value}")
    end

    def tag
      assert_last_commit_is_bump!
      Shell.run("git", "tag", version.tag)
    end

    def untag
      assert_last_commit_is_bump!
      Shell.run("git", "tag", "--delete", version.tag)
    end

    def reset
      assert_last_commit_is_bump!
      Shell.run("git", "reset", "--quiet", "--mixed", "HEAD~1")
      Shell.run("git", "restore", version.path.to_s)
    end

    def revert
      assert_last_commit_is_bump!
      Shell.run("git", "revert", "HEAD", "--no-edit")
    end

    private

    def assert_last_commit_is_bump!
      result = Shell.capture("git", "log", "-1", "--pretty=%B")
      raise "Failed to read last commit message" unless result.success?

      bump = result.output.strip.start_with?(BUMP_MESSAGE_PREFIX)
      raise "Last commit does not appear to be a version bump." unless bump
    end
  end
end
