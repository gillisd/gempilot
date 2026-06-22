module Gempilot
  ## A class or module constant resolved within a gem's namespace.
  ##
  ## Wraps raw user input (a bare suffix like +Services::Auth+ or a
  ## fully-qualified +MyGem::Services::Auth+) together with the gem's module
  ## and require path, and derives the qualified constant, file paths, and
  ## namespace pieces from a single parse.
  ##
  ## Every constant is rooted at the gem's module: bare input is prefixed with
  ## it, while input already starting with the gem's root segment is left as
  ## is. Rooting is matched on the first segment only, so an extension gem
  ## whose module is +My::Gem+ accepts any +My::...+ constant.
  GemConstant = Data.define(:input, :gem_module, :require_path) do
    using String::Inflectable

    ## The fully-qualified constant, rooted at the gem module.
    def qualified
      input.start_with?("#{root_segment}::") ? input : "#{gem_module}::#{input}"
    end

    ## Namespace segments preceding the final constant name.
    def namespaces
      parts[0...-1]
    end

    ## The final class or module name.
    def name
      parts.last
    end

    ## Path to the constant's source file, e.g. +lib/my_gem/services/auth.rb+.
    def lib_path
      "#{File.join("lib", *path_segments)}.rb"
    end

    ## Path to the constant's test file for +framework+ (+:rspec+ or
    ## +:minitest+); correct for multi-segment (hyphenated) gem modules.
    def test_path(framework)
      rest = path_segments.drop(require_path.split("/").length)
      if framework == :rspec
        "#{File.join("spec", require_path, *rest)}_spec.rb"
      else
        "#{File.join("test", require_path, *rest)}_test.rb"
      end
    end

    private

    def root_segment
      gem_module.split("::").first
    end

    def parts
      qualified.split("::")
    end

    def path_segments
      parts.map(&:underscore)
    end
  end
end
