require "pathname"
require "warning"

module Gempilot
  ## Introspects a gem project to discover its name, module, and version.
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
      lib_project.basename.to_s
    end

    def klass
      Object.const_get(name.camelize)
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

    def with_version_file
      version.path.open(File::RDWR, 0o644) do |f|
        f.flock File::LOCK_EX
        yield f
        f.truncate(f.pos)
      end
    end

    def fetch_lib_project
      files = lib.glob("*.rb")
      dirs = files.map { it.sub_ext("") }.select(&:directory?)
      case dirs.count
      in 0 then raise ProjectIntrospectionError, "Could not identify project dir"
      in (2..)
        msg = "Found more than one possible project name:\n  - #{dirs.join("\n  - ")}"
        raise ProjectIntrospectionError, msg
      in 1 then dirs.first
      end
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
