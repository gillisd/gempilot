require "spec_helper"

RSpec.describe Gempilot::CLI::Commands::Create do
  subject(:command) { described_class.new }

  let(:valid_opts) do
    ["--author", "Test", "--email", "t@t.com", "--summary", "test",
     "--test", "minitest", "--no-exe", "--no-git"]
  end

  describe "gem name validation" do
    context "when name contains spaces" do
      it "exits with an error" do
        expect(command.main(["A foo"])).to eq(1)
      end

      it "prints a helpful message" do
        expect { command.main(["A foo"]) }.to output(/Invalid gem name/).to_stdout
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
        expect { command.main(valid_opts + ["my-gem"]) }.not_to output(/Invalid gem name/).to_stdout
      end
    end

    context "when name is valid lowercase with underscores" do
      it "does not fail validation" do
        expect { command.main(valid_opts + ["my_gem"]) }.not_to output(/Invalid gem name/).to_stdout
      end
    end
  end
end
