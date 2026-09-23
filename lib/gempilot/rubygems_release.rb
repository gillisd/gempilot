module Gempilot
  ##
  # Pushes every gem of the version being released to RubyGems. Backs the
  # +release:rubygem_push+ task in place of bundler's, which pushes only the
  # single gem its own +build+ task produced. A project that builds several
  # gems per version (platform gems carrying a compiled executable alongside
  # the plain ruby gem) needs all of them pushed, so this globs +pkg/+ for the
  # packages of that version: <tt>name-version.gem</tt> and
  # <tt>name-version-platform.gem</tt>. The glob is scoped to the exact version
  # because +pkg/+ is never emptied between releases; a looser
  # <tt>name-version*.gem</tt> would also sweep up <tt>name-1.2.30.gem</tt> and
  # <tt>name-1.2.3.1.gem</tt> and re-push versions already on RubyGems. Finding
  # no package at all aborts the release, since a release that published
  # nothing must not report success.
  class RubygemsRelease
    include StrictShell

    attr_reader :project

    def initialize(project)
      @project = project
    end

    def push
      paths = packages
      raise "No packages for #{name_and_version} found in pkg/; run rake build first" if paths.empty?

      paths.each { sh "gem", "push", it.to_s }
    end

    private

    def name_and_version
      "#{project.name} #{project.version_value}"
    end

    def packages
      stem = "#{project.name}-#{project.version_value}"
      project.root.glob("pkg/{#{stem}.gem,#{stem}-*.gem}").sort
    end
  end
end
