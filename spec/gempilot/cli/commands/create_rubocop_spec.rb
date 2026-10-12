require "spec_helper"
require "stringio"

RSpec.describe Gempilot::CLI::Commands::Create do
  let(:command) { described_class.new(stdout: stdout) }

  let(:stdout) { StringIO.new }

  let(:create_args) do
    ["--author", "Test Author", "--email", "test@example.com",
     "--summary", "A test gem", "--ruby-version", "3.4.8",
     "--test", "minitest", "--no-exe", "--no-git", "test_gem"]
  end

  before { allow(command).to receive(:sh) }

  describe "generated .rubocop.yml" do
    let(:rubocop_yml) { File.read("test_gem/.rubocop.yml") }

    context "with the default options" do
      before { command.main(create_args) }

      it "inspects the core extensions directory" do
        expect(rubocop_yml).not_to include("core_ext")
      end

      it "inspects the rake library directory" do
        expect(rubocop_yml).not_to include("rakelib")
      end

      it "leaves no template tags" do
        expect(rubocop_yml).not_to include("<%")
      end

      it "loads the minitest plugin" do
        expect(rubocop_yml).to include("rubocop-minitest")
      end

      it "places the redundant line break cop in the layout department" do
        expect(rubocop_yml).not_to include("Style/RedundantLineBreak")
      end
    end

    context "with the rspec framework" do
      before { command.main([*create_args[...-1], "--test", "rspec", "test_gem"]) }

      it "loads the rspec plugin" do
        expect(rubocop_yml).to include("rubocop-rspec")
      end

      it "omits the minitest plugin" do
        expect(rubocop_yml).not_to include("rubocop-minitest")
      end
    end
  end
end
