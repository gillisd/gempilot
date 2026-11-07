module Gempilot
  ## Pushes the current branch and a release tag to the branch's git remote.
  ## Backs the +release:source_control_push+ task. Idempotent: pushing an
  ## already-pushed branch or tag is a no-op, so re-running a release never
  ## fails on an existing tag (unlike bundler's +already_tagged?+ guard, which
  ## skips the push entirely once the tag exists locally). From a detached
  ## HEAD, such as a CI checkout of the tag, there is no branch to push, so
  ## only the tag goes to +origin+.
  class Origin
    attr_reader :tag

    def initialize(tag)
      @tag = tag
    end

    def push
      Shell.run("git", "push", remote, "refs/heads/#{branch}") if branch
      Shell.run("git", "push", remote, "refs/tags/#{tag}")
    end

    private

    def branch
      return @branch if defined?(@branch)

      @branch = attached_branch
    end

    def attached_branch
      result = Shell.capture("git", "symbolic-ref", "--quiet", "--short", "HEAD")
      result.output.strip if result.success?
    end

    def remote
      @remote ||= configured_remote || "origin"
    end

    def configured_remote
      return unless branch

      result = Shell.capture("git", "config", "--get", "branch.#{branch}.remote")
      result.output.strip if result.success?
    end
  end
end
