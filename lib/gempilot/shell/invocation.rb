require "shellwords"

module Gempilot
  module Shell
    ## A command and how to run it.
    ##
    ##   Gempilot::Shell::Invocation.new(command: ["git", "commit", "-m", "Bump version"],
    ##                                   chdir: nil, env: {}, unbundled: false).to_s
    ##   # => "git commit -m Bump\\ version"
    Invocation = Data.define(:command, :chdir, :env, :unbundled) do
      def to_s
        command.shelljoin
      end
    end
  end
end
