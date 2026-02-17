
require "test_helper"

module Gempilot
  class GemspecEditorTest < Minitest::Test
    def test_buffer_initialization
      buffer = Gempilot::Buffer.new("hello")
      assert_equal "hello", buffer.read
    end
  end
end
