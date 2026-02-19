require 'pathname'

class String
  def increment_version
    components = split('.')
    components[-1] = (components[-1].to_i + 1).to_s
    components.join('.')
  end

  def to_pathname
    Pathname.new(self)
  end
end

namespace :version do
  root_path = Pathname.new(__dir__).join('../')
  project_path = root_path.join('lib/dialed')
  version_path = project_path.join('version.rb')
  file version_path

  desc "Bump the current version by smallest increment"
  task :bump => [version_path] do
    gem_exists_command = "gem info -i --version '#{Dialed::VERSION}' dialed | xargs test true =="
    puts gem_exists_command

    gem_exists = system gem_exists_command
    puts "Gem exists? #{gem_exists}"

    warn 'You may be bumping a version that does not yet exist - perhaps you need to reset or revert?' unless gem_exists

    version_path.open(File::RDWR | File::CREAT, 0644) do |f|
      f.flock(File::LOCK_EX)
      current_version = Dialed::VERSION
      source = f.read

      begin
        next_version = current_version.increment_version
        new_source = source.gsub(current_version, next_version)

        if new_source == source
          puts "Warning: No version string was replaced in #{version_path}"
        else
          f.rewind
          f.write(new_source)
          f.truncate(f.pos)
          puts "Version bumped from #{current_version} to #{next_version}"
        end
      rescue => e
        f.rewind
        f.write(source)
        raise e
      end
    end
  end

  desc 'Displays the current version'
  task :current do
    puts "Current version: #{Dialed::VERSION}"
  end

  desc "Undo the last version bump commit"
  task :revert do
    # Check if the last commit was a version bump
    last_commit_message = `git log -1 --pretty=%B`.strip
    if last_commit_message.start_with?('Bumped version to ')
      puts "Reverting last version bump commit..."
      sh "git revert HEAD --no-edit"
      puts "Version reverted successfully"
    else
      puts "Last commit doesn't appear to be a version bump. Aborting."
    end
  end

  desc "Commit the current version change"
  task :commit => [version_path] do
    load version_path
    sh "git add #{version_path}"
    sh "git commit -m 'Bumped version to #{Dialed::VERSION}'"
    puts "Change to version.rb committed successfully!"
  end
end

namespace :release do
  desc 'Bumps version, commits it, and then releases gem'
  task :full => ['version:bump', 'version:commit', :release]
end