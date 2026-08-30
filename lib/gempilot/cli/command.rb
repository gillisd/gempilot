require "command_kit/command"
require "command_kit/colors"
require "command_kit/interactive"
require "command_kit/bug_report"

module Gempilot
  class CLI
    ## Base command class for all gempilot subcommands.
    class Command < CommandKit::Command
      include CommandKit::Colors
      include CommandKit::Interactive
      include CommandKit::BugReport

      bug_report_url "https://github.com/gillisd/gempilot/issues/new"
    end
  end
end
