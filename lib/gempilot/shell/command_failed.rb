module Gempilot
  module Shell
    ## Raised by Shell.run when a command fails.
    ##
    ##   Gempilot::Shell.run("git", "checkout", "no-such-branch")
    ##   # Gempilot::Shell::CommandFailed: Command failed with status (1): [git checkout no-such-branch]
    class CommandFailed < Error
      attr_reader :invocation, :status

      def initialize(invocation, status)
        @invocation = invocation
        @status = status
        super("Command failed with status (#{status.exitstatus.inspect}): [#{invocation}]")
      end
    end
  end
end
