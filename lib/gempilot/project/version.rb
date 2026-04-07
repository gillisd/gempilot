module Gempilot
  class Project
    Version = Data.define(:path, :value) do
      def tag
        "v#{value}"
      end

      def bump(segment = :patch)
        major, minor, patch = value.split(".").map(&:to_i)
        new_value = case segment.to_sym
                    when :major then "#{major + 1}.0.0"
                    when :minor then "#{major}.#{minor + 1}.0"
                    when :patch then "#{major}.#{minor}.#{patch + 1}"
                    else raise ArgumentError, "Unknown segment #{segment.inspect}. Use :major, :minor, or :patch"
                    end
        with(value: new_value)
      end

      alias_method :next_version, :bump
    end.freeze
  end
end
