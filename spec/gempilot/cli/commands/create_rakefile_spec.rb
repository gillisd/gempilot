require "spec_helper"
require "stringio"

RSpec.describe Gempilot::CLI::Commands::Create do
  let(:command) { described_class.new(stdout: StringIO.new) }
  let(:sh_calls) { [] }

  def create(name, *flags)
    command.main([
                   "--author", "Test Author", "--email", "test@example.com",
                   "--summary", "A test gem", "--ruby-version", "3.4.8",
                   "--test", "minitest", "--no-exe", "--no-git", *flags, name
                 ])
  end

  before { allow(command).to receive(:sh) { |*args| sh_calls << args } }

  describe "generated Rakefile zeitwerk wiring" do
    context "with a flat gem name" do
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

    context "with a hyphenated gem name" do
      before { create("gempilot-encryption") }

      it "instantiates the zeitwerk task" do
        expect(File.read("gempilot-encryption/Rakefile")).to include("Gempilot::ZeitwerkTask.new")
      end
    end
  end

  describe "generated Rakefile version wiring" do
    let(:rakefile) { File.read("test_gem/Rakefile") }

    before { create("test_gem") }

    it "requires the gempilot version task library" do
      expect(rakefile).to include('require "gempilot/version_task"')
    end

    it "instantiates the version task" do
      expect(rakefile).to include("Gempilot::VersionTask.new")
    end
  end

  describe "generated Rakefile test wiring" do
    context "with the rspec framework" do
      let(:rakefile) { File.read("test_gem/Rakefile") }

      before { create("test_gem", "--test", "rspec") }

      it "requires the rspec rake task library" do
        expect(rakefile).to include("rspec/core/rake_task")
      end

      it "defines the spec task" do
        expect(rakefile).to include(":spec")
      end

      it "omits minitest" do
        expect(rakefile).not_to include("minitest")
      end
    end
  end
end
