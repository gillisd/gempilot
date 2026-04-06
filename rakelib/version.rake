VERSION_PATTERN = /VERSION\s*=\s*"(\d+\.\d+\.\d+)"/
VERSION_PATH = File.expand_path("../lib/gempilot/version.rb", __dir__).freeze

def show_version
  require_relative "../lib/gempilot/version"
  puts "Current version: #{Gempilot::VERSION}"
end

def read_version(path)
  source = File.read(path)
  match = source.match(VERSION_PATTERN)
  abort "Could not find VERSION in #{path}" unless match
  [source, match[1]]
end

def next_patch(version)
  parts = version.split(".").map(&:to_i)
  parts[-1] += 1
  parts.join(".")
end

def write_version(path, content)
  File.open(path, File::WRONLY | File::TRUNC) do |f|
    f.flock(File::LOCK_EX)
    f.write(content)
  end
end

def bump_version(path)
  source, old_ver = read_version(path)
  new_ver = next_patch(old_ver)
  write_version(path, source.sub(old_ver, new_ver))
  puts "Version bumped from #{old_ver} to #{new_ver}"
end

def commit_version(path)
  require_relative "../lib/gempilot/version"
  sh "git add #{path}"
  sh "git commit -m 'Bump version to #{Gempilot::VERSION}'"
  puts "Version change committed."
end

def revert_version_bump
  last_message = `git log -1 --pretty=%B`.strip
  abort "Last commit does not appear to be a version bump." unless last_message.start_with?("Bump version to ")
  sh "git revert HEAD --no-edit"
  puts "Version bump reverted."
end

namespace :version do
  desc "Display the current version"
  task(:current) { show_version }
  desc "Bump the patch version"
  task(:bump) { bump_version(VERSION_PATH) }
  desc "Commit the version change"
  task(:commit) { commit_version(VERSION_PATH) }
  desc "Revert the last version bump commit"
  task(:revert) { revert_version_bump }
end

namespace :release do
  desc "Bump version, commit, and release"
  task full: ["version:bump", "version:commit", :release]
end
