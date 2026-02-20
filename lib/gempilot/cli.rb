require "command_kit/commands"
require "command_kit/commands/auto_load"
require "command_kit/options/version"

require_relative "../gempilot"

module Gempilot
  class CLI
    include CommandKit::Commands
    include CommandKit::Commands::AutoLoad.new(
      dir: "#{__dir__}/cli/commands",
      namespace: "#{self}::Commands"
    ) { |autoload|
      autoload.command "bump",    "Bump",    "bump.rb",    summary: "Bump the gem version"
      autoload.command "console", "Console", "console.rb", summary: "Start an interactive console"
      autoload.command "create",  "Create",  "create.rb",  summary: "Scaffold a new gem"
      autoload.command "destroy", "Destroy", "destroy.rb",
                       summary: "Remove a generated class, module, or command"
      autoload.command "new",     "New",     "new.rb",
                       summary: "Generate a class, module, or command"
      autoload.command "release", "Release", "release.rb", summary: "Release the gem to RubyGems"
    }
    include CommandKit::Options::Version

    command_name "gempilot"
    version Gempilot::VERSION
  end
end
