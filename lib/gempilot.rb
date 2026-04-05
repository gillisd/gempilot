require "zeitwerk"

autoload :Open3, "open3"

module Gempilot
  LOADER = Zeitwerk::Loader.for_gem.freeze
  LOADER.inflector.inflect("cli" => "CLI")
  LOADER.setup

  ROOT = File.expand_path(File.join(__dir__, "..")).freeze

  class Error < StandardError; end
  class CommandError < Error; end
end
