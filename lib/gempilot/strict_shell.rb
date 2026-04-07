require "rake"

module Gempilot
  module StrictShell
    include Rake::FileUtilsExt

    private

    def sh(*args, **kwargs)
      super do |ok, res|
        raise "Command #{args.join(" ").inspect} failed (exit #{res.exitstatus})" unless ok

        [ok, res]
      end
    end
  end
end
