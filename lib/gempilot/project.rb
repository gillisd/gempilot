module Gempilot
  ##
  # Introspects a gem project to discover its name, require path, autoload
  # root, and version. Works for both regular gems (+lib/my_gem.rb+) and
  # extension gems whose entry point nests deeper (+lib/my_gem/extension.rb+
  # for +my_gem-extension+).
  #
  # The version is read by loading +version.rb+ under a throwaway module, so
  # the project's module name is never needed and reloading after a bump
  # never redefines a real constant.
  class Project
    class ProjectIntrospectionError < StandardError; end

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

    def require_path
      project_segments.join("/")
    end

    ##
    # The directory a loader set up with +for_gem+ or +for_gem_extension+
    # manages: the parent of the project's namespace directory.
    def autoload_root
      lib_project.parent
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
      path = lib_project.join("version.rb").tap { verify_existence! it }
      Version.new(path:, value: version_defined_in(path))
    end

    # Loads the version file under an anonymous module so the modules it opens
    # live there instead of in the real namespace, then walks that private
    # module tree down to VERSION.
    def version_defined_in(path)
      sandbox = Module.new
      load path.to_s, sandbox
      version_in(sandbox) || raise(ProjectIntrospectionError, "Expected #{path} to define a VERSION constant")
    end

    def version_in(mod)
      return mod.const_get(:VERSION, false) if mod.const_defined?(:VERSION, false)

      mod.constants(false)
         .map { mod.const_get(it, false) }
         .grep(Module)
         .filter_map { version_in(it) }
         .first
    end

    def verify_existence!(path)
      return true if @verifications.member? path

      raise ProjectIntrospectionError, "Expected #{path} to exist but does not" unless path.exist?

      @verifications.add path
    end
  end
end
