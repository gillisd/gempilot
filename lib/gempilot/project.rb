require "warning"

module Gempilot
  ## Introspects a gem project to discover its name, module, and version.
  ## Works for both regular gems (+lib/my_gem.rb+) and extension gems whose
  ## entry point nests deeper (+lib/my_gem/extension.rb+ for +my_gem-extension+).
  class Project
    class ProjectIntrospectionError < StandardError; end

    REDEFINITION_WARNING = /previous definition of VERSION was here/
    REINITIALIZATION_WARNING = /already initialized constant [^\s]+::VERSION/
    private_constant :REDEFINITION_WARNING, :REINITIALIZATION_WARNING

    using String::Inflectable

    attr_reader :root

    def initialize(root = Dir.pwd)
      @root = Pathname(root)
      @verifications = Set.new
    end

    def lib
      root.join("lib")
          .tap { verify_existence! it }
    end

    def lib_project
      @lib_project ||= fetch_lib_project
    end

    def name
      project_segments.join("-")
    end

    def klass
      Object.const_get(project_segments.map(&:camelize).join("::"))
    end

    def version
      @version ||= fetch_version
    end

    def refresh_version!
      @version = fetch_version
    end

    def increment_version
      version.next_version
    end

    def version_tag = version.tag

    def version_value = version.value

    def write_version!(old_version, new_version)
      with_version_file do |f|
        source = f.read

        unless source.match?(Regexp.escape(old_version.value))
          abort "Expected to find #{old_version.value} in #{f.path} but did not"
        end

        f.rewind
        f.write source.gsub(old_version.value, new_version.value)
      end
    end

    private

    def project_segments
      lib_project.relative_path_from(lib).each_filename.to_a
    end

    def with_version_file
      version.path.open(File::RDWR, 0o644) do |f|
        f.flock File::LOCK_EX
        yield f
        f.truncate(f.pos)
      end
    end

    def fetch_lib_project
      dirs = shallowest_entry_dirs
      case dirs.count
      in 0 then raise ProjectIntrospectionError, "Could not identify project dir"
      in (2..)
        msg = "Found more than one possible project name:\n  - #{dirs.join("\n  - ")}"
        raise ProjectIntrospectionError, msg
      in 1 then dirs.first
      end
    end

    def shallowest_entry_dirs
      entry_dirs.group_by { depth_below_lib(it) }
                .min_by(&:first)
                &.last || []
    end

    def entry_dirs
      lib.glob("**/*.rb")
         .map { it.sub_ext("") }
         .select(&:directory?)
    end

    def depth_below_lib(path)
      path.relative_path_from(lib).each_filename.count
    end

    def fetch_version
      Warning.ignore(REDEFINITION_WARNING)
      Warning.ignore(REINITIALIZATION_WARNING)
      path = lib_project
             .join("version.rb")
             .tap { verify_existence! it }
             .tap { load it }

      value = klass.const_get(:VERSION)

      Version.new(path:, value:)
    end

    def verify_existence!(path)
      return true if @verifications.member? path

      raise ProjectIntrospectionError, "Expected #{path} to exist but does not" unless path.exist?

      @verifications.add path
    end
  end
end
