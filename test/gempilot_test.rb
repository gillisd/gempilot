# frozen_string_literal: true

require_relative "test_helper"

class TestGempilot < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Gempilot::VERSION
  end

  def test_root_is_defined
    assert_kind_of String, Gempilot::ROOT
    assert File.directory?(Gempilot::ROOT)
  end
end
