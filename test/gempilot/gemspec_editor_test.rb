# frozen_string_literal: true

require "test_helper"

module Gempilot
  class GemspecEditorTest < Minitest::Test
    attr_reader :gemspec_path

    def setup
      @gemspec_path = Pathname.new(__dir__).parent.parent.join("gempilot.gemspec")
      # Do nothing
    end

    def teardown
      # Do nothing
    end

    def test_metadata
      Gempilot::GemspecEditor.new(gemspec_path) do |e|
        e
      end
    end
  end
end
