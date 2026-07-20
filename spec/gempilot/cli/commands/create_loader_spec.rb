require "spec_helper"
require "stringio"

RSpec.describe Gempilot::CLI::Commands::Create do
  subject(:command) { described_class.new(stdout: StringIO.new) }

  def create(name)
    command.main([
                   "--author", "Test Author", "--email", "test@example.com",
                   "--summary", "A test gem", "--ruby-version", "3.4.8",
                   "--test", "minitest", "--no-exe", "--no-git", name
                 ])
  end

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
    end

    context "when the gem is a hyphenated extension" do
      before { create("gempilot-encryption") }

      it "configures the extension loader with a tap setup" do
        entry = File.read("gempilot-encryption/lib/gempilot/encryption.rb")
        expect(entry).to include("for_gem_extension(Gempilot).tap(&:setup)")
      end
    end
  end
end
