# frozen_string_literal: true

# $LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require 'zeitwerk'
require "gempilot"

require_relative '../../junk/minitest-activate'

loader = Zeitwerk::Loader.new
loader.push_dir 'test/gempilot', namespace: Gempilot
loader.setup
require "minitest/autorun"
