##
# Represents the project structure used by rake tasks.
#
# Holds the extracted +Version+ value object so that specs and rake support
# classes can +require+ it without loading the full Rakefile (which triggers
# filesystem introspection and constant redefinition warnings).
class Project
  ##
  # Immutable value object pairing a version file path with its string value.
  #
  # +path+ is a +Pathname+ pointing to the +version.rb+ source file.
  # +value+ is the raw version string, e.g. <tt>"1.2.3"</tt> or
  # <tt>"0.0.4.dev3"</tt>.
  Version = Data.define(:path, :value) do
    ##
    # Returns the version string prefixed with <tt>v</tt>, e.g. <tt>"v1.2.3"</tt>.
    def tag
      "v#{value}"
    end

    ##
    # Returns a new +Version+ with the last numeric segment incremented by one.
    #
    # Works with plain semver (<tt>"1.2.3"</tt> => <tt>"1.2.4"</tt>) and
    # pre-release suffixes (<tt>"0.0.4.dev3"</tt> => <tt>"0.0.4.dev4"</tt>).
    def next_version
      value.split(".") => [*rest, last_part]
      new_value = last_part.gsub(/\d+/) { it.to_i + 1 }
                           .then { [*rest, it] }
                           .join(".")
      with(value: new_value)
    end
  end.freeze
end
