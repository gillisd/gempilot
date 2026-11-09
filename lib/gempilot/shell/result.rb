module Gempilot
  module Shell
    ## A captured command's standard output and exit status.
    ##
    ##   result = Gempilot::Shell.capture("git", "config", "--get", "no.such.key")
    ##   result.output   # => ""
    ##   result.success? # => false
    Result = Data.define(:output, :status) do
      def success?
        status.success?
      end
    end
  end
end
