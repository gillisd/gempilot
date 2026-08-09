require "spec_helper"

RSpec.describe Gempilot::BetterleaksTask do
  around do |example|
    old_app = Rake.application
    Rake.application = Rake::Application.new
    example.run
  ensure
    Rake.application = old_app
  end

  before { described_class.new }

  it "defines the betterleaks task" do
    expect(Rake::Task).to be_task_defined("betterleaks")
  end

  context "when betterleaks is not installed" do
    around do |example|
      original = ENV.fetch("PATH", nil)
      Dir.mktmpdir("empty_path") do |dir|
        ENV["PATH"] = dir
        example.run
      end
    ensure
      ENV["PATH"] = original
    end

    it "skips the scan without raising" do
      expect { Rake::Task["betterleaks"].invoke }.not_to raise_error
    end
  end
end
