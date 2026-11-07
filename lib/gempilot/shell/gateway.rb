require "bundler"
require "open3"

module Gempilot
  module Shell
    ## Runs commands as real processes. Shell uses it unless a test replaces it.
    class Gateway
      def run(invocation)
        in_environment(invocation) do
          begin
            pid = Process.spawn(invocation.env, *invocation.command, **spawn_options(invocation))
            Status.from_process(Process.wait2(pid).last)
          rescue SystemCallError
            Status.exited(127)
          end
        end
      end

      def capture(invocation)
        in_environment(invocation) do
          begin
            output, status = Open3.capture2(invocation.env, *invocation.command, **spawn_options(invocation))
            Result.new(output:, status: Status.from_process(status))
          rescue SystemCallError
            Result.new(output: "", status: Status.exited(127))
          end
        end
      end

      def exec(invocation)
        in_environment(invocation) { Kernel.exec(invocation.env, *invocation.command, **spawn_options(invocation)) }
      end

      private

      def in_environment(invocation, &)
        invocation.unbundled ? Bundler.with_unbundled_env(&) : yield
      end

      def spawn_options(invocation)
        invocation.chdir ? { chdir: invocation.chdir.to_s } : {}
      end
    end
  end
end
