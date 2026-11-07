require "spec_helper"

# Pushes to real bare repositories standing in for remotes.
RSpec.describe Gempilot::Origin do
  include GitHelpers

  let(:origin) { described_class.new("v1.2.3") }

  around do |example|
    Dir.mktmpdir("origin_spec") { |dir| Dir.chdir(dir) { example.run } }
  end

  def add_remote(name)
    git("init", "--quiet", "--bare", "#{name}.git")
    git("remote", "add", name, "#{name}.git")
  end

  def refs_on(remote)
    git_output("--git-dir=#{remote}.git", "for-each-ref", "--format=%(refname)").split
  end

  before do
    git("init", "--quiet", "-b", "main", ".")
    git("config", "user.email", "test@test.com")
    git("config", "user.name", "Test")
    git("commit", "--allow-empty", "--quiet", "-m", "init")
    git("tag", "v1.2.3")
    add_remote("origin")
  end

  describe "#push" do
    it "pushes the branch to origin" do
      origin.push
      expect(refs_on("origin")).to include("refs/heads/main")
    end

    it "pushes the tag to origin" do
      origin.push
      expect(refs_on("origin")).to include("refs/tags/v1.2.3")
    end

    it "stays idempotent on re-run" do
      origin.push
      expect { described_class.new("v1.2.3").push }.not_to raise_error
    end

    context "when the branch has a configured remote" do
      before do
        add_remote("upstream")
        git("config", "branch.main.remote", "upstream")
      end

      it "pushes the branch and tag to that remote" do
        origin.push
        expect(refs_on("upstream")).to contain_exactly("refs/heads/main", "refs/tags/v1.2.3")
      end

      it "pushes nothing to origin" do
        origin.push
        expect(refs_on("origin")).to be_empty
      end
    end

    context "when HEAD is detached" do
      before { git("checkout", "--detach", "--quiet") }

      it "pushes only the tag to origin" do
        origin.push
        expect(refs_on("origin")).to contain_exactly("refs/tags/v1.2.3")
      end
    end

    context "when the push fails" do
      before { git("remote", "set-url", "origin", "missing.git") }

      it "raises" do
        expect { origin.push }.to raise_error(Gempilot::Shell::CommandFailed)
      end
    end
  end
end
