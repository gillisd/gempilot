module Gempilot
  ## Runs external commands for gempilot.
  ##
  ##   Gempilot::Shell.run("git", "--version")
  ##   # git version 2.55.0
  ##   # => #<data Gempilot::Shell::Status exitstatus=0, success=true>
  ##
  ##   Gempilot::Shell.capture("git", "branch", "--show-current").output
  ##   # => "main\n"
  module Shell
    class << self
      attr_writer :gateway

      ## The gateway commands run through: Gateway, unless replaced with +with_gateway+.
      def gateway
        @gateway ||= Gateway.new
      end

      ## Runs a command, streaming its output. Raises CommandFailed if it fails.
      ##
      ##   Gempilot::Shell.run("git", "checkout", "no-such-branch")
      ##   # error: pathspec 'no-such-branch' did not match any file(s) known to git
      ##   # Gempilot::Shell::CommandFailed: Command failed with status (1): [git checkout no-such-branch]
      def run(*command, chdir: nil, env: {}, unbundled: false)
        invocation = Invocation.new(command:, chdir:, env:, unbundled:)
        status = gateway.run(invocation)
        raise CommandFailed.new(invocation, status) unless status.success?

        status
      end

      ## Runs a command and returns its standard output. Never raises.
      ##
      ##   result = Gempilot::Shell.capture("git", "config", "--get", "user.name")
      ##   result.output   # => "Ada Lovelace\n"
      ##   result.success? # => true
      def capture(*command, chdir: nil, env: {}, unbundled: false)
        gateway.capture(Invocation.new(command:, chdir:, env:, unbundled:))
      end

      ## Replaces the current process with a command.
      ##
      ##   Gempilot::Shell.exec("bin/console", unbundled: true)
      def exec(*command, chdir: nil, env: {}, unbundled: false)
        gateway.exec(Invocation.new(command:, chdir:, env:, unbundled:))
      end

      ## Runs the block with commands going through +gateway+.
      ##
      ##   stubs = Gempilot::Shell::StubGateway.new
      ##   stubs.stub("gh", "release", "list").to_return(output: "v1.0.0\tLatest\n")
      ##
      ##   Gempilot::Shell.with_gateway(stubs) { Gempilot::Shell.capture("gh", "release", "list").output }
      ##   # => "v1.0.0\tLatest\n"
      def with_gateway(gateway)
        previous = self.gateway
        begin
          self.gateway = gateway
          yield
        ensure
          self.gateway = previous
        end
      end
    end
  end
end
