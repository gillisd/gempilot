module Gempilot
  ## Arithmetic over the three version shapes gempilot accepts: release
  ## (+1.2.3+), tiny release (+1.2.3.1+), and dev prerelease (+1.2.3.dev1+).
  ##
  ## Every bump returns the smallest version of the requested shape that is
  ## strictly greater than the current version under RubyGems ordering, so
  ## bumping always moves a project forward: a dev bump previews the next
  ## patch (+1.2.3+ to +1.2.4.dev1+) and numeric bumps finalize a dev cycle
  ## (+1.2.4.dev2+ to +1.2.4+ for +:patch+).
  SegmentedVersion = Data.define(:major, :minor, :patch, :tiny, :dev) do
    def self.parse(string)
      format = /\A(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)(?:\.(?<tiny>\d+)|\.dev(?<dev>\d+))?\z/
      match = format.match(string)
      raise ArgumentError, "cannot parse version: #{string.inspect}" unless match

      new(**match.named_captures.to_h { |name, digits| [name.to_sym, digits&.to_i] })
    end

    def bump(segment)
      case segment.to_sym
      when :major then bump_major
      when :minor then bump_minor
      when :patch then bump_patch
      when :tiny  then bump_tiny
      when :dev   then bump_dev
      else raise ArgumentError, "Unknown segment #{segment.inspect}. Use :major, :minor, :patch, :tiny, or :dev"
      end
    end

    def to_s
      [major, minor, patch, tiny, ("dev#{dev}" if dev)].compact.join(".")
    end

    private

    def bump_major
      return finalize if dev && minor.zero? && patch.zero?

      with(major: major + 1, minor: 0, patch: 0, tiny: nil, dev: nil)
    end

    def bump_minor
      return finalize if dev && patch.zero?

      with(minor: minor + 1, patch: 0, tiny: nil, dev: nil)
    end

    def bump_patch
      dev ? finalize : with(patch: patch + 1, tiny: nil)
    end

    def bump_tiny
      with(tiny: (tiny || 0) + 1, dev: nil)
    end

    def bump_dev
      dev ? with(dev: dev + 1) : with(patch: patch + 1, tiny: nil, dev: 1)
    end

    def finalize
      with(tiny: nil, dev: nil)
    end
  end.freeze
end
