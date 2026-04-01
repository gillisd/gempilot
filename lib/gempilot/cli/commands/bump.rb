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
          segment = validate_segment(segment)
          version_path = find_version_file
          old_version, new_version = bump_version(version_path, segment)
          print_bump_result(old_version, new_version)
        end

        private

        def validate_segment(segment)
          segment = segment.downcase
          return segment if %w[patch minor major].include?(segment)

          puts colors.red("Unknown segment '#{segment}'. Use patch, minor, or major.")
          exit 1
        end

        def print_bump_result(old_version, new_version)
          label = colored_gem_name
          from = format_version_segment(" from ", colors.yellow(old_version))
          to = format_version_segment(" to ", colors.green(new_version))
          puts colors.bright_white("Bumped ") + label + from + to
        end

        def colored_gem_name
          colors.bold(colors.cyan(@gem_name))
        end

        def format_version_segment(prefix, colored_version)
          colors.bright_white(prefix) + colored_version
        end

        def find_version_file
          path = File.join("lib", @require_path, "version.rb")
          unless File.exist?(path)
            puts colors.red("Version file not found at #{path}")
            exit 1
          end
          path
        end

        def bump_version(path, segment)
          old_version = read_current_version(path)
          new_version = increment(old_version, segment)
          write_new_version(path, new_version)
          [old_version, new_version]
        end

        def read_current_version(path)
          source = File.read(path)
          match = source.match(VERSION_PATTERN)

          unless match
            puts colors.red("Could not find VERSION = \"x.y.z\" in #{path}")
            exit 1
          end

          match[1]
        end

        def write_new_version(path, new_version)
          File.open(path, File::RDWR, 0o644) do |f|
            f.flock(File::LOCK_EX)
            content = f.read
            f.rewind
            f.write(content.sub(VERSION_PATTERN, "VERSION = \"#{new_version}\""))
            f.truncate(f.pos)
          end
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
