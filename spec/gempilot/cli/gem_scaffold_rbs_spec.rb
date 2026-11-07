require "spec_helper"
require "stringio"

RSpec.describe Gempilot::CLI::GemScaffold do
  let(:command) { described_class.new(stdout: StringIO.new) }

  def create(name)
    command.main([
                   "--author", "Test Author", "--email", "test@example.com",
                   "--summary", "A test gem", "--ruby-version", "3.4.8",
                   "--test", "minitest", "--no-exe", "--no-git", name
                 ])
  end

  before { create("test_gem") }

  describe "generated Rakefile rbs wiring" do
    let(:rakefile) { File.read("test_gem/Rakefile") }

    it "requires the gempilot rbs task library" do
      expect(rakefile).to include('require "gempilot/rbs_task"')
    end

    it "instantiates the rbs task" do
      expect(rakefile).to include("Gempilot::RBSTask.new")
    end

    it "validates rbs in the default task" do
      expect(rakefile).to include('task default: [:test, :rubocop, "rbs:validate"]')
    end
  end

  describe "generated CI workflow" do
    it "validates rbs" do
      expect(File.read("test_gem/.github/workflows/ci.yml")).to include("bundle exec rake rbs:validate")
    end
  end

  describe "generated Gemfile" do
    it "bundles rbs" do
      expect(File.read("test_gem/Gemfile")).to match(/^gem "rbs"$/)
    end
  end

  describe "generated .gitignore" do
    it "ignores the installed rbs collection" do
      expect(File.readlines("test_gem/.gitignore", chomp: true)).to include("/.gem_rbs_collection/")
    end
  end

  describe "generated bin/setup" do
    it "runs rake setup after installing the bundle" do
      lines = File.readlines("test_gem/bin/setup", chomp: true)
      expect(lines.last(2)).to eq(["bundle install", "bundle exec rake setup"])
    end
  end
end
