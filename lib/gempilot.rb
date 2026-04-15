require "zeitwerk"

autoload :Open3, "open3"

# CLI toolkit for creating and managing Ruby gems.
module Gempilot
  ROOT = Pathname(__dir__).parent.expand_path.freeze
  LOADER = Zeitwerk::Loader.for_gem.tap do |l|
    l.inflector.inflect("cli" => "CLI")
    l.push_dir ROOT.join("lib/core_ext")
    l.collapse ROOT.join("lib/core_ext/*/refinements")
    l.setup
  end

  class Error < StandardError; end
  class CommandError < Error; end
end
