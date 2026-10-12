require "spec_helper"
require "stringio"

RSpec.describe Gempilot::CLI::Commands::Console do
  let(:command) { described_class.new(stdout: StringIO.new) }

  before do
    File.write("my_gem.gemspec", 'Gem::Specification.new { |s| s.name = "my_gem" }')
    FileUtils.mkdir_p("test")
  end

  context "without a gemspec" do
    before { FileUtils.rm("my_gem.gemspec") }

    it "exits with status 1" do
      expect(command.main([])).to eq(1)
    end
  end

  context "without a console script" do
    it "exits with status 1" do
      expect(command.main([])).to eq(1)
    end
  end
end
