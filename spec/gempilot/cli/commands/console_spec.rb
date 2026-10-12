require "spec_helper"

RSpec.describe Gempilot::CLI::Commands::Console do
  include FileUtils

  subject(:command) { described_class.new }

  before do
    File.write("my_gem.gemspec", 'Gem::Specification.new { |s| s.name = "my_gem" }')
    mkdir_p("test")
  end

  context "without a gemspec" do
    before { rm("my_gem.gemspec") }

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
