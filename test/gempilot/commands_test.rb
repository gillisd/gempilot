# frozen_string_literal: true

require "test_helper"

module Gempilot
  class CommandsTest < Minitest::Test
    include Gempilot::Commands

    def test_sh_raises_on_missing_command
      assert_raises(Gempilot::Error) do
        sh "nonexistent_command_that_does_not_exist_xyz"
      end
    rescue Gempilot::Error
      # expected
    end
  end
end
