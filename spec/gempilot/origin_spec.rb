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
    let(:pushes) { [] }

    before { allow(origin).to receive(:sh) { |*command| pushes << command.drop(2) } }

    it "pushes the current branch, then the tag, to origin" do
      origin.push
      expect(pushes).to eq([%w[origin refs/heads/main], %w[origin refs/tags/v1.2.3]])
    end

    context "when the branch has a configured remote" do
      before do
        system("git", "remote", "add", "upstream", ".")
        system("git", "config", "branch.main.remote", "upstream")
      end

      it "pushes to that remote" do
        origin.push
        expect(pushes).to eq([%w[upstream refs/heads/main], %w[upstream refs/tags/v1.2.3]])
      end
    end

    context "when HEAD is detached" do
      before { system("git", "checkout", "--detach", "--quiet") }

      it "pushes only the tag, to origin" do
        origin.push
        expect(pushes).to eq([%w[origin refs/tags/v1.2.3]])
      end
    end
  end

  describe "#push against a real remote" do
    before do
      system("git", "clone", "--quiet", "--bare", ".", "origin.git")
      system("git", "remote", "add", "origin", "origin.git")
      system("git", "tag", "v1.2.3")
    end

    it "lands the tag on the remote" do
      origin.push
      expect(`git --git-dir=origin.git tag`.strip).to eq("v1.2.3")
    end

    it "stays idempotent on re-run" do
      origin.push
      expect { described_class.new("v1.2.3").push }.not_to raise_error
    end
  end
end
