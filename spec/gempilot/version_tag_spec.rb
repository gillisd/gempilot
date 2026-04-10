require "rake"
require "tmpdir"
require "gempilot/project/version"
require "gempilot/version_tag"

DIRTY_STAGING_ERROR = /staging area must be clean/

RSpec.describe Gempilot::VersionTag do
  let(:version_path) { Pathname("lib/my_gem/version.rb") }
  let(:version_value) { "1.0.0" }
  let(:version) { Gempilot::Project::Version.new(path: version_path, value: version_value) }

  subject(:version_tag) { described_class.new(version) }

  around do |example|
    Dir.mktmpdir("version_tag_spec") do |tmpdir|
      Dir.chdir(tmpdir) do
        example.run
      end
    end
  end

  before do
    system("git init --quiet .")
    system("git config user.email 'test@test.com'")
    system("git config user.name 'Test'")
    FileUtils.mkdir_p("lib/my_gem")
    File.write(version_path.to_s, "module MyGem\n  VERSION = \"#{version_value}\".freeze\nend\n")
  end

  describe "#create" do
    context "when staging area is clean" do
      before do
        system("git commit --allow-empty -m 'Initial commit' --quiet")
      end

      it "commits the version file with the correct message" do
        version_tag.create
        log = `git log -1 --pretty=%B`.strip
        expect(log).to eq("Bump version to #{version_value}")
      end

      it "includes the version file in the commit" do
        version_tag.create
        committed_files = `git diff-tree --no-commit-id --name-only -r HEAD`.strip
        expect(committed_files).to include(version_path.to_s)
      end
    end

    context "when staging area has staged changes" do
      before do
        File.write("other.txt", "data")
        system("git add other.txt")
      end

      it "raises an error" do
        expect { version_tag.create }.to raise_error(RuntimeError, DIRTY_STAGING_ERROR)
      end
    end
  end

  describe "#tag" do
    before { version_tag.create }

    it "creates a git tag matching the version tag" do
      version_tag.tag
      tags = `git tag`.strip.split("\n")
      expect(tags).to include("v#{version_value}")
    end
  end

  describe "#untag" do
    before do
      version_tag.create
      version_tag.tag
    end

    it "removes the version tag" do
      version_tag.untag
      tags = `git tag`.strip.split("\n")
      expect(tags).not_to include("v#{version_value}")
    end
  end

  describe "#reset" do
    before do
      system("git add lib/my_gem/version.rb && git commit -m 'Initial commit' --quiet")
      File.write(version_path.to_s, "module MyGem\n  VERSION = \"2.0.0\".freeze\nend\n")
      version_tag.create
    end

    it "removes the last commit" do
      version_tag.reset
      expect(`git log --oneline`.lines.count).to eq(1)
    end
  end

  describe "#revert" do
    before do
      system("git add lib/my_gem/version.rb && git commit -m 'Initial commit' --quiet")
      File.write(version_path.to_s, "module MyGem\n  VERSION = \"2.0.0\".freeze\nend\n")
      version_tag.create
    end

    it "creates a revert commit" do
      version_tag.revert
      log = `git log -1 --pretty=%B`.strip
      expect(log).to start_with("Revert")
    end
  end

  describe "#tag when last commit is not a version bump" do
    before do
      File.write("README.md", "init")
      system("git add README.md && git commit -m 'Not a version bump' --quiet")
    end

    it "aborts with an error" do
      expect { version_tag.tag }.to raise_error(SystemExit)
    end
  end
end
