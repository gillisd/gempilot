# frozen_string_literal: true

require 'zeitwerk'

autoload :Open3, 'open3'
loader = Zeitwerk::Loader.for_gem
loader.setup

module Gempilot
  class Error < StandardError; end

  # Your code goes here...
  def cool
    foo = 'bar'

    puts 2 + 2
    foo
  end

  def butter
    puts 'butter'
  end

  def again
    foo = 'bar'

    stuff = 1 + 1
    puts stuff
  end
end
