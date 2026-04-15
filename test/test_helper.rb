require "forwardable"
require "zeitwerk"
require "minitest/autorun"
require_relative "../lib/gempilot"

module Support
end

Zeitwerk::Loader.new.tap do |l|
  l.push_dir "test/support", namespace: Support
  l.setup
end
