# frozen_string_literal: true

require 'zeitwerk'

autoload :Open3, 'open3'
loader = Zeitwerk::Loader.for_gem
loader.setup

module Gempilot
  class Error < StandardError; end
end
