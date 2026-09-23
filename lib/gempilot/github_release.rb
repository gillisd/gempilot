module Gempilot
  ## Manages GitHub releases for a version tag. Tags naming a prerelease
  ## version (e.g. +v1.2.4.dev1+) are created as GitHub prereleases.
  class GithubRelease
    include StrictShell

    attr_reader :tag

    def initialize(tag)
      @tag = tag
    end

    def create
      sh "gh", "release", "create",
         "--generate-notes", "--fail-on-no-commits",
         *prerelease_flag,
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

    private

    def prerelease_flag
      Gem::Version.new(tag.delete_prefix("v")).prerelease? ? ["--prerelease"] : []
    end
  end
end
