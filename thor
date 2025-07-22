#!/usr/bin/env ruby
# frozen_string_literal: true

require "thor"

class Generator < Thor
  desc "a generator", "a generator"
  def generate(foo)
    p foo
  end
end
