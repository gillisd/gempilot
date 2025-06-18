#!/usr/bin/env ruby

require 'thor'

class Generator < Thor

  desc 'a generator', 'a generator'
  def generate(foo)
    p foo
  end
end
