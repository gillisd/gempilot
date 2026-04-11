require "command_kit/commands"
require "command_kit/commands/auto_load"
require "command_kit/options/version"
require_relative '../gempilot'

module Gempilot
  ## Top-level command router for the gempilot CLI.
  class CLI
    include CommandKit::Commands
    include CommandKit::Commands::AutoLoad.new(
      dir: "#{__dir__}/cli/commands",
      namespace: "#{self}::Commands",
    )
    include CommandKit::Options::Version

    command_name "gempilot"
    version Gempilot::VERSION
  end
end
