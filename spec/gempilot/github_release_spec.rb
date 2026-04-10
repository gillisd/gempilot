require "rake"
require "gempilot/github_release"

RSpec.describe Gempilot::GithubRelease do
  let(:tag) { "v1.0.0" }
  let(:release) { described_class.new(tag) }

  before do
    allow(release).to receive(:sh)
  end

  describe "#create" do
    it "pushes commits, pushes tags, then creates a release", :aggregate_failures do
      release.create
      expect(release).to have_received(:sh).with("git", "push").ordered
      expect(release).to have_received(:sh).with("git", "push", "--tags").ordered
      create_args = ["gh", "release", "create", "--generate-notes", "--fail-on-no-commits", tag]
      expect(release).to have_received(:sh).with(*create_args).ordered
    end
  end

  describe "#destroy" do
    it "deletes the release with tag cleanup" do
      args = ["gh", "release", "delete", "--yes", "--cleanup-tag", tag]
      release.destroy
      expect(release).to have_received(:sh).with(*args)
    end
  end

  describe "#list" do
    it "lists all releases" do
      release.list
      expect(release).to have_received(:sh).with("gh", "release", "list")
    end
  end
end
