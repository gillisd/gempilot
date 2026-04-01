require "command_kit/command"
require "command_kit/colors"
require "command_kit/interactive"
require "command_kit/bug_report"

module Gempilot
  class CLI
    class Command < CommandKit::Command
      include CommandKit::Colors
      include CommandKit::Interactive
      include CommandKit::BugReport

      bug_report_url "https://github.com/dgillis/gempilot/issues/new"
    end
  end
end
