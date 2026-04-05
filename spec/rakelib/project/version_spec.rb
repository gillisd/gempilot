require "rake"
require_relative "../../../data/templates/gem/rakelib/project_version"

RSpec.describe Project::Version do
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

      it { is_expected.to eq(described_class.new(path: path, value: "0.0.4.dev4")) }
    end

    context "with a multi-digit patch" do
      let(:value) { "1.0.99" }

      it { is_expected.to eq(described_class.new(path: path, value: "1.0.100")) }
    end
  end
end
