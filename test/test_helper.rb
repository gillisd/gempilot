require "rake"
require "forwardable"
require "minitest/autorun"
require_relative "../lib/gempilot"

module Support
end

loader = Zeitwerk::Loader.new
loader.push_dir "test/support", namespace: Support
loader.setup
