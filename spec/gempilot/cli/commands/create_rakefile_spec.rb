require "spec_helper"
require "stringio"

RSpec.describe Gempilot::CLI::Commands::Create do
  let(:command) { described_class.new(stdout: StringIO.new) }
  let(:sh_calls) { [] }

  def create(name)
    command.main([
                   "--author", "Test Author", "--email", "test@example.com",
                   "--summary", "A test gem", "--ruby-version", "3.4.8",
                   "--test", "minitest", "--no-exe", "--no-git", name
                 ])
  end

  before { allow(command).to receive(:sh) { |*args| sh_calls << args } }

  describe "generated Rakefile zeitwerk wiring" do
    let(:rakefile) { File.read("test_gem/Rakefile") }

    before { create("test_gem") }

    it "requires the gempilot zeitwerk task library" do
      expect(rakefile).to include('require "gempilot/zeitwerk_task"')
    end

    it "instantiates the zeitwerk task" do
      expect(rakefile).to include("Gempilot::ZeitwerkTask.new")
    end

    it "does not inline the zeitwerk namespace" do
      expect(rakefile).not_to include("namespace :zeitwerk")
    end
  end
end
