##
# Wraps Rake::FileUtilsExt#sh to raise on non-zero exit status
# instead of returning a failure tuple.
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
