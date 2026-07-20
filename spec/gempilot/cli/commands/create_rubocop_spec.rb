require "spec_helper"
require "stringio"

RSpec.describe Gempilot::CLI::Commands::Create do
  subject(:command) { described_class.new(stdout: stdout) }

  let(:stdout) { StringIO.new }

  let(:create_args) do
    ["--author", "Test Author", "--email", "test@example.com",
     "--summary", "A test gem", "--ruby-version", "3.4.8",
     "--test", "minitest", "--no-exe", "--no-git", "test_gem"]
  end

  describe "generated .rubocop.yml" do
    let(:rubocop_yml) { File.read("test_gem/.rubocop.yml") }

    before { command.main(create_args) }

    it "does not exclude core_ext" do
      expect(rubocop_yml).not_to include("core_ext")
    end

    it "does not exclude rakelib" do
      expect(rubocop_yml).not_to include("rakelib")
    end
  end
end
