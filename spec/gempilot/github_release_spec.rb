require "spec_helper"

# gh release create/delete publish to GitHub, so these run against a
# StubGateway: only the stubbed gh commands may run.
RSpec.describe Gempilot::GithubRelease do
  let(:tag) { "v1.0.0" }
  let(:release) { described_class.new(tag) }
  let(:stubs) { Gempilot::Shell::StubGateway.new }

  around do |example|
    Gempilot::Shell.with_gateway(stubs) { example.run }
  end

  describe "#create" do
    let(:command) { ["gh", "release", "create", "--generate-notes", "--fail-on-no-commits", tag] }

    before { stubs.stub(*command) }

    it "creates a release with generated notes" do
      release.create
      expect(stubs).to be_ran(*command)
    end

    it "runs no other command" do
      release.create
      expect(stubs.invocations.map(&:command)).to eq([command])
    end

    context "with a dev prerelease tag" do
      let(:tag) { "v1.2.4.dev1" }
      let(:command) do
        ["gh", "release", "create", "--generate-notes", "--fail-on-no-commits", "--prerelease", tag]
      end

      it "marks the release as a prerelease" do
        release.create
        expect(stubs).to be_ran(*command)
      end
    end

    context "with a tiny release tag" do
      let(:tag) { "v1.2.3.1" }

      it "does not mark the release as a prerelease" do
        release.create
        expect(stubs).to be_ran(*command)
      end
    end

    context "when gh fails" do
      before { stubs.stub(*command).to_return(exitstatus: 1) }

      it "raises" do
        expect { release.create }.to raise_error(Gempilot::Shell::CommandFailed)
      end
    end
  end

  describe "#destroy" do
    let(:command) { ["gh", "release", "delete", "--yes", "--cleanup-tag", tag] }

    before { stubs.stub(*command) }

    it "deletes the release with tag cleanup" do
      release.destroy
      expect(stubs).to be_ran(*command)
    end
  end

  describe "#list" do
    before { stubs.stub("gh", "release", "list") }

    it "lists all releases" do
      release.list
      expect(stubs).to be_ran("gh", "release", "list")
    end
  end
end
