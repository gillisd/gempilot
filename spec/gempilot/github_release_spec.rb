require "spec_helper"

RSpec.describe Gempilot::GithubRelease do
  let(:tag) { "v1.0.0" }

  let(:release) { described_class.new(tag) }

  before do
    allow(release).to receive(:sh)
  end

  describe "#create" do
    it "creates a release with generated notes" do
      release.create
      args = ["gh", "release", "create", "--generate-notes", "--fail-on-no-commits", tag]
      expect(release).to have_received(:sh).with(*args)
    end

    it "does not push git refs itself" do
      release.create
      expect(release).not_to have_received(:sh).with("git", any_args)
    end

    context "with a dev prerelease tag" do
      let(:tag) { "v1.2.4.dev1" }

      it "marks the release as a prerelease" do
        release.create
        args = ["gh", "release", "create", "--generate-notes", "--fail-on-no-commits", "--prerelease", tag]
        expect(release).to have_received(:sh).with(*args)
      end
    end

    context "with a tiny release tag" do
      let(:tag) { "v1.2.3.1" }

      it "does not mark the release as a prerelease" do
        release.create
        args = ["gh", "release", "create", "--generate-notes", "--fail-on-no-commits", tag]
        expect(release).to have_received(:sh).with(*args)
      end
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
