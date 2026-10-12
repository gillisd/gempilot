require "spec_helper"
require "stringio"

RSpec.describe Gempilot::CLI::Commands::Create do
  let(:command) { described_class.new(stdout: StringIO.new) }

  def create(name)
    command.main([
                   "--author", "Test Author", "--email", "test@example.com",
                   "--summary", "A test gem", "--ruby-version", "3.4.8",
                   "--test", "minitest", "--no-exe", "--no-git", name
                 ])
  end

  before { allow(command).to receive(:sh) }

  describe "generated loader setup" do
    context "when the gem is flat" do
      before { create("test_gem") }

      it "configures the loader with a tap setup" do
        main_rb = File.read("test_gem/lib/test_gem.rb")
        expect(main_rb).to include("LOADER = Zeitwerk::Loader.for_gem.tap(&:setup)")
      end

      it "does not call setup on the LOADER constant" do
        main_rb = File.read("test_gem/lib/test_gem.rb")
        expect(main_rb).not_to include("LOADER.setup")
      end

      it "requires zeitwerk" do
        expect(File.read("test_gem/lib/test_gem.rb")).to include('require "zeitwerk"')
      end

      it "ignores no paths" do
        expect(File.read("test_gem/lib/test_gem.rb")).not_to include("LOADER.ignore")
      end

      it "builds a gem loader" do
        expect(File.read("test_gem/lib/test_gem.rb")).to include("Zeitwerk::Loader.for_gem")
      end

      it "skips the extension loader" do
        expect(File.read("test_gem/lib/test_gem.rb")).not_to include("for_gem_extension")
      end
    end

    context "when the gem is a hyphenated extension" do
      before { create("gempilot-encryption") }

      it "configures the extension loader with a tap setup" do
        entry = File.read("gempilot-encryption/lib/gempilot/encryption.rb")
        expect(entry).to include("for_gem_extension(Gempilot).tap(&:setup)")
      end

      it "builds an extension loader" do
        entry = File.read("gempilot-encryption/lib/gempilot/encryption.rb")
        expect(entry).to include("for_gem_extension")
      end

      it "extends the base namespace" do
        entry = File.read("gempilot-encryption/lib/gempilot/encryption.rb")
        expect(entry).to include("Gempilot")
      end

      it "points the shim at the nested entry file" do
        shim = File.read("gempilot-encryption/lib/gempilot-encryption.rb")
        expect(shim).to include('require "gempilot/encryption"')
      end

      it "keeps zeitwerk out of the shim" do
        shim = File.read("gempilot-encryption/lib/gempilot-encryption.rb")
        expect(shim).not_to include("zeitwerk")
      end
    end
  end
end
