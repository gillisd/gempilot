require "rake/tasklib"
require_relative "../gempilot"

module Gempilot
  ## Rake task that scans the repository for committed secrets using
  ## betterleaks (https://github.com/betterleaks/betterleaks).
  ##
  ## Owned by gempilot and consumed by generated gems via
  ## <tt>require "gempilot/betterleaks_task"; Gempilot::BetterleaksTask.new</tt>.
  ## betterleaks is a standalone binary, not a gem, so the task degrades
  ## gracefully: when betterleaks is absent from +PATH+ it prints an install
  ## hint and succeeds instead of failing, keeping the task usable on machines
  ## and Ruby engines where the scanner is unavailable.
  class BetterleaksTask < Rake::TaskLib
    def initialize
      super
      define_scan_task
    end

    private

    def define_scan_task
      desc "Scan the repository for committed secrets with betterleaks"
      task(:betterleaks) { scan }
    end

    def scan
      return warn_missing unless betterleaks_available?

      sh "betterleaks", "git", "--redact", "--verbose"
    end

    def betterleaks_available?
      ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |dir|
        File.executable?(File.join(dir, "betterleaks"))
      end
    end

    def warn_missing
      warn "betterleaks not found on PATH; skipping secret scan " \
           "(install: brew install betterleaks)"
    end
  end
end
