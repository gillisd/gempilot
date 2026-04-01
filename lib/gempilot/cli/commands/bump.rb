require_relative "../command"
require_relative "../gem_context"

module Gempilot
  class CLI
    module Commands
      ## Bumps the VERSION constant in an existing gem's +version.rb+.
      class Bump < Command
        include GemContext

        usage "[options] [SEGMENT]"
        description "Bump the gem version (patch by default, or minor/major)"

        examples [
          "",
          "patch",
          "minor",
          "major",
        ]

        argument :segment, required: false,
                           desc: "Version segment to bump: patch (default), minor, or major"

        VERSION_PATTERN = /VERSION\s*=\s*"(\d+\.\d+\.\d+)"/
        def run(segment = "patch")
          detect_gem_context

          segment = segment.downcase
          unless %w[patch minor major].include?(segment)
            puts colors.red("Unknown segment '#{segment}'. Use patch, minor, or major.")
            exit 1
          end

          version_path = find_version_file
          old_version, new_version = bump_version(version_path, segment)

          puts colors.bright_white("Bumped ") +
               colors.bold(colors.cyan(@gem_name)) +
               colors.bright_white(" from ") +
               colors.yellow(old_version) +
               colors.bright_white(" to ") +
               colors.green(new_version)
        end

        private

        def find_version_file
          path = File.join("lib", @require_path, "version.rb")
          unless File.exist?(path)
            puts colors.red("Version file not found at #{path}")
            exit 1
          end
          path
        end

        def bump_version(path, segment)
          source = File.read(path)
          match = source.match(VERSION_PATTERN)

          unless match
            puts colors.red("Could not find VERSION = \"x.y.z\" in #{path}")
            exit 1
          end

          old_version = match[1]
          new_version = increment(old_version, segment)

          File.open(path, File::RDWR, 0o644) do |f|
            f.flock(File::LOCK_EX)
            content = f.read
            new_content = content.sub(VERSION_PATTERN, "VERSION = \"#{new_version}\"")
            f.rewind
            f.write(new_content)
            f.truncate(f.pos)
          end

          [old_version, new_version]
        end

        def increment(version, segment)
          major, minor, patch = version.split(".").map(&:to_i)

          case segment
          when "major" then "#{major + 1}.0.0"
          when "minor" then "#{major}.#{minor + 1}.0"
          when "patch" then "#{major}.#{minor}.#{patch + 1}"
          end
        end
      end
    end
  end
end
