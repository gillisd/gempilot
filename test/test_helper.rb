# frozen_string_literal: true

# $LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "rake"
require "forwardable"
require "pathname"
require_relative "../../junk/minitest-activate"
require_relative "../lib/gempilot"

loader = Zeitwerk::Loader.new
loader.push_dir "test/gempilot", namespace: Gempilot
loader.setup
require_relative "../../modern_rake/test/support/environment"
require_relative "../../modern_rake/test/support/environment_assertions"
require_relative "../../modern_rake/test/support/env_helper"
