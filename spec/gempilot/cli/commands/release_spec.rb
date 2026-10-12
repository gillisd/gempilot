require "spec_helper"
require "stringio"

RSpec.describe Gempilot::CLI::Commands::Release do
  let(:command) { described_class.new(stdout: StringIO.new) }
  let(:system_calls) { [] }

  before do
    allow(command).to receive(:system) { |*args| system_calls << args }
    File.write("my_gem.gemspec", 'Gem::Specification.new { |s| s.name = "my_gem" }')
    FileUtils.mkdir_p("test")
  end

  context "without a gemspec" do
    before { FileUtils.rm("my_gem.gemspec") }

    it "exits with status 1" do
      expect(command.main([])).to eq(1)
    end
  end

  it "delegates to the rake release task" do
    command.main([])
    expect(system_calls).to include(["bundle", "exec", "rake", "release"])
  end
end
