require "spec_helper"

RSpec.describe Gempilot::Origin do
  let(:origin) { described_class.new("v1.2.3") }

  around do |example|
    Dir.mktmpdir("origin_spec") { |dir| Dir.chdir(dir) { example.run } }
  end

  before do
    system("git", "init", "--quiet", "-b", "main", ".")
    system("git", "config", "user.email", "test@test.com")
    system("git", "config", "user.name", "Test")
    system("git", "commit", "--allow-empty", "--quiet", "-m", "init")
  end

  describe "#push" do
    before { allow(origin).to receive(:sh) }

    it "pushes the current branch, then the tag, to the resolved remote", :aggregate_failures do
      origin.push
      expect(origin).to have_received(:sh).with("git", "push", "origin", "refs/heads/main").ordered
      expect(origin).to have_received(:sh).with("git", "push", "origin", "refs/tags/v1.2.3").ordered
    end
  end

  describe "#push to a configured remote" do
    before do
      allow(origin).to receive(:sh)
      system("git", "remote", "add", "upstream", ".")
      system("git", "config", "branch.main.remote", "upstream")
    end

    it "pushes to the branch's configured remote", :aggregate_failures do
      origin.push
      expect(origin).to have_received(:sh).with("git", "push", "upstream", "refs/heads/main")
      expect(origin).to have_received(:sh).with("git", "push", "upstream", "refs/tags/v1.2.3")
    end
  end

  describe "#push from a detached HEAD" do
    it "raises before attempting any push" do
      system("git", "checkout", "--detach", "--quiet")
      expect { described_class.new("v1.2.3").push }.to raise_error(/detached HEAD/i)
    end
  end

  describe "#push against a real remote" do
    before do
      system("git", "clone", "--quiet", "--bare", ".", "origin.git")
      system("git", "remote", "add", "origin", "origin.git")
      system("git", "tag", "v1.2.3")
    end

    it "lands the tag on the remote and stays idempotent on re-run", :aggregate_failures do
      origin.push
      expect(`git --git-dir=origin.git tag`.strip).to eq("v1.2.3")
      expect { described_class.new("v1.2.3").push }.not_to raise_error
    end
  end
end
