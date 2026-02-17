# frozen_string_literal: true

require "zeitwerk"

autoload :Open3, "open3"
loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect("cli" => "CLI")
loader.setup

module Gempilot
  ROOT = File.expand_path(File.join(__dir__, ".."))

  class Error < StandardError; end
  class CommandError < Error; end
end
