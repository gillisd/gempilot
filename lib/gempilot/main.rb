#!/usr/bin/env ruby

# frozen_string_literal: true

require "open3"
require "optparse"
require "fileutils"
require "tempfile"
require "stringio"
require "pathname"

autoload :RuboCop, "rubocop"
