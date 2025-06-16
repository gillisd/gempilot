# frozen_string_literal: true

require 'test_helper'

module Gempilot
  class CommandsTest < Minitest::Test
    include Gempilot::Commands

    def setup
      # Do nothing
    end

    def teardown
      # Do nothing
    end

    def test_config
      bundle_config_set 'foo', 'bar'
    end

    def test_bundle_add
      gems = %w[rails sinatra]
      # assert_output(/bundle add rails sinatra/) do
        bundle_add *gems
      # end
    # rescue Gempilot::CommandError => e
    #   assert_match(/Command not found: #{command.join(' ')}/, e.message)
    end

    def test_command
      sh 'bundle binstub --force bundler'
      sh 'bin/bundle binstub --force rake'
      sh 'bin/bundle config set path vendor'
    end
  end
end
