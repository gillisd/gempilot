require "spec_helper"

RSpec.describe Gempilot::CLI::Commands::Create do
  include FileUtils

  subject(:command) { described_class.new }

  let(:sh_calls) { [] }

  def create_with_git(name, branch: "master")
    command.main([
                   "--author", "Test Author", "--email", "test@example.com",
                   "--summary", "A test gem", "--ruby-version", "3.4.8",
                   "--test", "minitest", "--no-exe", "--git", "--branch", branch, name
                 ])
  end

  def git_init_call
    sh_calls.find { |call| call[0] == "git" && call[1] == "init" }
  end

  def committed_message
    sh_calls.find { |call| call[0] == "git" && call[1] == "commit" }&.last
  end

  def seed_repo_with_history(dir)
    mkdir_p(dir)
    Dir.chdir(dir) do
      system("git", "init", "-q", "-b", "master")
      system("git", "config", "user.email", "seed@example.com")
      system("git", "config", "user.name", "Seed")
      touch("README.md")
      system("git", "add", ".")
      system("git", "commit", "-q", "-m", "Pre-existing history")
    end
  end

  before { allow(command).to receive(:sh) { |*args| sh_calls << args } }

  describe "git commit message" do
    context "when the target has no prior history" do
      it "commits with the initial-commit message" do
        create_with_git("test_gem")
        expect(committed_message).to eq("Initial commit.")
      end
    end

    context "when the target already has commit history" do
      before { seed_repo_with_history("test_gem") }

      it "does not reuse the initial-commit message" do
        create_with_git("test_gem")
        expect(committed_message).not_to eq("Initial commit.")
      end

      it "names the commit after the scaffolded gem" do
        create_with_git("test_gem")
        expect(committed_message).to eq("Add test_gem gem scaffolding.")
      end
    end
  end

  describe "git branch" do
    context "with a custom branch" do
      before { create_with_git("test_gem", branch: "develop") }

      it "passes the branch flag" do
        expect(git_init_call).to include("-b")
      end

      it "initializes the requested branch" do
        expect(git_init_call).to include("develop")
      end
    end
  end
end
