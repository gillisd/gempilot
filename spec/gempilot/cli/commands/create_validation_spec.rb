require "spec_helper"
require "stringio"

RSpec.describe Gempilot::CLI::Commands::Create do
  subject(:command) { described_class.new(stdout: stdout) }

  let(:stdout) { StringIO.new }

  describe "gem name validation" do
    context "when name contains spaces" do
      it "exits with an error" do
        expect(command.main(["A foo"])).to eq(1)
      end

      it "prints a helpful message" do
        command.main(["A foo"])

        expect(stdout.string).to include("Invalid gem name")
      end
    end

    context "when name starts with uppercase" do
      it "exits with an error" do
        expect(command.main(["MyGem"])).to eq(1)
      end
    end

    context "when name starts with a digit" do
      it "exits with an error" do
        expect(command.main(["3gems"])).to eq(1)
      end
    end

    context "when name is valid lowercase with hyphens" do
      it "does not fail validation" do
        # Use --no-git and provide all required options to avoid prompts.
        # The command will proceed past validation (may fail later without
        # a real filesystem, but that's fine — we're testing validation).
        result = command.main([
          "--author", "Test",
          "--email", "t@t.com",
          "--summary", "test",
          "--test", "minitest",
          "--no-exe",
          "--no-git",
          "my-gem",
        ])

        expect(stdout.string).not_to include("Invalid gem name")
      end
    end

    context "when name is valid lowercase with underscores" do
      it "does not fail validation" do
        result = command.main([
          "--author", "Test",
          "--email", "t@t.com",
          "--summary", "test",
          "--test", "minitest",
          "--no-exe",
          "--no-git",
          "my_gem",
        ])

        expect(stdout.string).not_to include("Invalid gem name")
      end
    end
  end
end
