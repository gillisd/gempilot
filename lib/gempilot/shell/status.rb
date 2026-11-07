module Gempilot
  module Shell
    ## How a command exited.
    ##
    ##   Gempilot::Shell::Status.exited(1).success? # => false
    Status = Data.define(:exitstatus, :success) do
      def self.exited(exitstatus)
        new(exitstatus:, success: exitstatus.zero?)
      end

      def self.from_process(status)
        new(exitstatus: status.exitstatus, success: status.success?)
      end

      def success?
        success
      end
    end
  end
end
