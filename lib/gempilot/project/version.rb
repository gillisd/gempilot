module Gempilot
  class Project
    Version = Data.define(:path, :value) do
      def tag
        "v#{value}"
      end

      def bump(segment = :patch)
        case segment.to_sym
        when :major, :minor, :patch then bump_semver(segment)
        when :dev                   then bump_dev
        else raise ArgumentError, "Unknown segment #{segment.inspect}. Use :major, :minor, :patch, or :dev"
        end
      end

      private

      def bump_semver(segment)
        major, minor, patch = value.split(".").first(3).map(&:to_i)
        new_value = case segment.to_sym
                    when :major then "#{major + 1}.0.0"
                    when :minor then "#{major}.#{minor + 1}.0"
                    when :patch then "#{major}.#{minor}.#{patch + 1}"
                    end
        with(value: new_value)
      end

      def bump_dev
        if value.match?(/\.dev\d+\z/)
          with(value: value.sub(/\d+\z/) { it.to_i + 1 })
        else
          with(value: "#{value}.dev1")
        end
      end

      alias_method :next_version, :bump
    end.freeze
  end
end
