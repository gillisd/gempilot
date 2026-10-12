require "spec_helper"

RSpec.describe Gempilot::CLI::Commands::Release do
  include FileUtils

  subject(:command) { described_class.new }

  let(:system_calls) { [] }

  before do
    allow(command).to receive(:system) { |*args| system_calls << args }
    File.write("my_gem.gemspec", 'Gem::Specification.new { |s| s.name = "my_gem" }')
    mkdir_p("test")
  end

  context "without a gemspec" do
    before { rm("my_gem.gemspec") }

    it "exits with status 1" do
      expect(command.main([])).to eq(1)
    end
  end

  it "delegates to the rake release task" do
    command.main([])
    expect(system_calls).to include(["bundle", "exec", "rake", "release"])
  end
end
