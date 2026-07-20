require "open3"

module Gempilot
  ## Pushes the current branch and a release tag to the branch's git remote.
  ## Backs the +release:source_control_push+ task. Idempotent: pushing an
  ## already-pushed branch or tag is a no-op, so re-running a release never
  ## fails on an existing tag (unlike bundler's +already_tagged?+ guard, which
  ## skips the push entirely once the tag exists locally).
  class Origin
    include StrictShell

    attr_reader :tag

    def initialize(tag)
      @tag = tag
    end

    def push
      sh "git", "push", remote, "refs/heads/#{branch}"
      sh "git", "push", remote, "refs/tags/#{tag}"
    end

    private

    def branch
      @branch ||= capture("git", "rev-parse", "--abbrev-ref", "HEAD")
    end

    def remote
      @remote ||= configured_remote || "origin"
    end

    def configured_remote
      out, status = Open3.capture2("git", "config", "--get", "branch.#{branch}.remote")
      out.strip if status.success?
    end

    def capture(*args)
      out, status = Open3.capture2(*args)
      raise "Command #{args.join(" ").inspect} failed" unless status.success?

      out.strip
    end
  end
end
