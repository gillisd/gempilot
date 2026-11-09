module Gempilot
  module Shell
    ## Raised by a StubGateway when a command was not stubbed.
    ##
    ##   Gempilot::Shell.with_gateway(Gempilot::Shell::StubGateway.new) do
    ##     Gempilot::Shell.run("gh", "release", "create", "v1.0.1")
    ##   end
    ##   # Gempilot::Shell::UnregisteredCommand: Unregistered command: [gh release create v1.0.1]
    ##   #
    ##   # Stub it with:
    ##   #
    ##   #   stub("gh", "release", "create", "v1.0.1")
    class UnregisteredCommand < Error
      attr_reader :invocation

      def initialize(invocation)
        @invocation = invocation
        stub_call = "stub(#{invocation.command.map(&:inspect).join(", ")})"
        super("Unregistered command: [#{invocation}]\n\nStub it with:\n\n  #{stub_call}")
      end
    end
  end
end
