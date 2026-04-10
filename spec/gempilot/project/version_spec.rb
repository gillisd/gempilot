require "rake"
require "gempilot/project/version"

RSpec.describe Gempilot::Project::Version do
  let(:path) { Pathname("lib/my_gem/version.rb") }

  describe "#tag" do
    it "prepends v to the value" do
      version = described_class.new(path: path, value: "1.2.3")
      expect(version.tag).to eq("v1.2.3")
    end
  end

  describe "#next_version" do
    subject { described_class.new(path: path, value: value).next_version }

    context "with a simple semver" do
      let(:value) { "1.2.3" }

      it { is_expected.to eq(described_class.new(path: path, value: "1.2.4")) }
    end

    context "with a dev suffix" do
      let(:value) { "0.0.4.dev3" }

      it { is_expected.to eq(described_class.new(path: path, value: "0.0.5")) }
    end

    context "with a multi-digit patch" do
      let(:value) { "1.0.99" }

      it { is_expected.to eq(described_class.new(path: path, value: "1.0.100")) }
    end
  end

  describe "#bump" do
    context "with a simple semver" do
      subject { described_class.new(path: path, value: "1.2.3") }

      it "bumps patch by default" do
        expect(subject.bump.value).to eq("1.2.4")
      end

      it "bumps minor" do
        expect(subject.bump(:minor).value).to eq("1.3.0")
      end

      it "bumps major" do
        expect(subject.bump(:major).value).to eq("2.0.0")
      end

      it "starts a dev cycle with :dev" do
        expect(subject.bump(:dev).value).to eq("1.2.3.dev1")
      end
    end

    context "with a dev version" do
      subject { described_class.new(path: path, value: "3.1.4.dev2") }

      it "increments the dev number" do
        expect(subject.bump(:dev).value).to eq("3.1.4.dev3")
      end

      it "strips dev and bumps patch" do
        expect(subject.bump(:patch).value).to eq("3.1.5")
      end

      it "strips dev and bumps minor" do
        expect(subject.bump(:minor).value).to eq("3.2.0")
      end

      it "strips dev and bumps major" do
        expect(subject.bump(:major).value).to eq("4.0.0")
      end
    end

    it "accepts segment as a string" do
      version = described_class.new(path: path, value: "1.0.0")
      expect(version.bump("minor").value).to eq("1.1.0")
    end

    it "raises for an unknown segment" do
      version = described_class.new(path: path, value: "1.0.0")
      expect { version.bump(:hotfix) }.to raise_error(ArgumentError, /unknown segment/i)
    end
  end
end
