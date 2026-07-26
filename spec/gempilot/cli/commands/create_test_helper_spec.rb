require "spec_helper"
require "stringio"

RSpec.describe Gempilot::CLI::Commands::Create do
  subject(:command) { described_class.new(stdout: StringIO.new) }

  let(:create_args) do
    ["--author", "Test Author", "--email", "test@example.com",
     "--summary", "A test gem", "--ruby-version", "3.4.8",
     "--test", "minitest", "--no-exe", "--no-git", "--no-betterleaks", "test_gem"]
  end

  describe "generated minitest test_helper" do
    let(:test_helper) { File.read("test_gem/test/test_helper.rb") }
    let(:guarded_reporters) do
      <<~RUBY.chomp
        unless ENV["RM_INFO"]
          require "minitest/reporters"
          Minitest::Reporters.use! [Minitest::Reporters::DefaultReporter.new(color: true)]
        end
      RUBY
    end

    before { command.main(create_args) }

    it "activates reporters only when RM_INFO is absent" do
      expect(test_helper).to include(guarded_reporters)
    end

    it "still disables autoloaded plugins outside RubyMine" do
      expect(test_helper).to include('ENV["MT_NO_PLUGINS"] = "1" unless ENV["RM_INFO"]')
    end
  end
end
