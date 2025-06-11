# frozen_string_literal: true

module Foo
  require_relative "gempilot/version"
  require 'delegate'
  require 'observer'
end

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
