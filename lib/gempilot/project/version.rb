module Gempilot
  class Project
    ## The project's version file (+path+) and value. Bump arithmetic
    ## delegates to SegmentedVersion, so every bump moves strictly forward
    ## under RubyGems ordering.
    Version = Data.define(:path, :value) do
      def tag
        "v#{value}"
      end

      def bump(segment = :patch)
        with(value: SegmentedVersion.parse(value).bump(segment).to_s)
      end

      alias_method :next_version, :bump
    end.freeze
  end
end
