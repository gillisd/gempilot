require "spec_helper"

# Runs the installed gempilot create and checks the gem it leaves behind.
# Needs network access.
RSpec.describe "gempilot create", :integration do
  include E2EHelpers
  include GitHelpers

  context "with a single-word gem name" do
    let!(:create_run) { create("test_gem") }

    it "succeeds" do
      expect(create_run).to be_success
    end

    it "installs the rbs collection" do
      expect(Pathname("test_gem/.gem_rbs_collection")).to be_directory
    end

    it "commits the rbs collection config and lockfile" do
      tracked = run("git", "ls-files", "rbs_collection.yaml", "rbs_collection.lock.yaml", chdir: "test_gem")
      expect(tracked.output.split).to contain_exactly("rbs_collection.yaml", "rbs_collection.lock.yaml")
    end

    it "keeps the installed collection out of git" do
      expect(run("git", "check-ignore", "-q", ".gem_rbs_collection", chdir: "test_gem")).to be_success
    end

    it "leaves a clean working tree" do
      expect(run("git", "status", "--porcelain", chdir: "test_gem").output).to be_empty
    end

    it "makes the initial commit" do
      expect(run("git", "log", "--format=%s", chdir: "test_gem").output).to eq("Initial commit.\n")
    end

    it "passes its own default rake task" do
      expect(run("bundle", "exec", "rake", chdir: "test_gem")).to be_success
    end
  end

  context "with a hyphenated gem name" do
    before { create("gempilot-encryption") }

    it "passes its own default rake task" do
      expect(run("bundle", "exec", "rake", chdir: "gempilot-encryption")).to be_success
    end
  end

  context "with --branch" do
    before { create("test_gem", "--branch", "develop") }

    it "commits to that branch" do
      expect(run("git", "branch", "--show-current", chdir: "test_gem").output).to eq("develop\n")
    end
  end

  context "when the directory already has git history" do
    before do
      FileUtils.mkdir("test_gem")
      Dir.chdir("test_gem") do
        git("init", "--quiet", "-b", "master")
        git("-c", "user.name=Seed", "-c", "user.email=seed@example.com",
            "commit", "--allow-empty", "--quiet", "-m", "Pre-existing history")
      end
      create("test_gem")
    end

    it "names the commit after the gem" do
      expect(run("git", "log", "-1", "--format=%s", chdir: "test_gem").output).to eq("Add test_gem gem scaffolding.\n")
    end
  end

  context "when a step fails" do
    let!(:create_run) { create("test_gem", "--branch", "bad..name") }

    it "exits with an error" do
      expect(create_run).not_to be_success
    end

    it "names the failed command" do
      expect(create_run.output).to include("Command failed with status (128): [git init -q -b bad..name]")
    end
  end

  context "when run with bundle exec inside another gem's bundle" do
    before { create("host_gem") }

    it "sets up the new gem in its own bundle" do
      expect(run("bundle", "exec", "gempilot", "create", "--author", "Test Author", "--email", "test@example.com",
                 "--summary", "A test gem", "--test", "minitest", "--no-exe", "--git", "--branch", "master",
                 "nested_gem", chdir: "host_gem")).to be_success
    end
  end
end
