module Gempilot
  module Shell
    ## Fakes commands in tests, the way WebMock fakes HTTP. Stubbed commands
    ## return what you give them; any other command raises UnregisteredCommand.
    ##
    ##   stubs = Gempilot::Shell::StubGateway.new
    ##   stubs.stub("gh", "release", "create", "v1.0.0").to_return(exitstatus: 0)
    ##
    ##   Gempilot::Shell.with_gateway(stubs) { Gempilot::GithubRelease.new("v1.0.0").create }
    ##   stubs.ran?("gh", "release", "create", "v1.0.0") # => true
    class StubGateway
      ## A stubbed command's result. Succeeds with no output unless given +to_return+.
      ##
      ##   stubs.stub("bundle", "exec", "rake", "release").to_return(output: "", exitstatus: 1)
      class Stub
        attr_reader :result

        def initialize
          to_return
        end

        def to_return(output: "", exitstatus: 0)
          @result = Result.new(output:, status: Status.exited(exitstatus))
          self
        end
      end

      attr_reader :invocations

      def initialize
        @stubs = {}
        @invocations = []
      end

      def stub(*command)
        @stubs[command] = Stub.new
      end

      def ran?(*command)
        invocations.any? { it.command == command }
      end

      def run(invocation)
        result = respond_to(invocation)
        $stdout.write(result.output)
        result.status
      end

      def capture(invocation)
        respond_to(invocation)
      end

      def exec(invocation)
        respond_to(invocation).status
      end

      private

      def respond_to(invocation)
        invocations << invocation
        @stubs.fetch(invocation.command) { raise UnregisteredCommand, invocation }.result
      end
    end
  end
end
