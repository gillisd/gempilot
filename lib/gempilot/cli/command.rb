
require "command_kit/command"
require "command_kit/colors"

module Gempilot
  class CLI
    class Command < CommandKit::Command
      include CommandKit::Colors
    end
  end
end
