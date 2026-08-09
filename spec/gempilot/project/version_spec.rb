require "spec_helper"

RSpec.describe Gempilot::Project::Version do
  let(:path) { Pathname("lib/my_gem/version.rb") }

  def version(value)
    described_class.new(path: path, value: value)
  end

  describe "#tag" do
    it "prepends v to the value" do
      expect(version("1.2.3").tag).to eq("v1.2.3")
    end
  end

  describe "#bump" do
    transitions = {
      "1.2.3" => { major: "2.0.0", minor: "1.3.0", patch: "1.2.4", tiny: "1.2.3.1", dev: "1.2.4.dev1" },
      "1.2.3.1" => { major: "2.0.0", minor: "1.3.0", patch: "1.2.4", tiny: "1.2.3.2", dev: "1.2.4.dev1" },
      "1.2.4.dev2" => { major: "2.0.0", minor: "1.3.0", patch: "1.2.4", tiny: "1.2.4.1", dev: "1.2.4.dev3" },
      "1.3.0.dev2" => { major: "2.0.0", minor: "1.3.0", patch: "1.3.0", tiny: "1.3.0.1", dev: "1.3.0.dev3" },
      "2.0.0.dev2" => { major: "2.0.0", minor: "2.0.0", patch: "2.0.0", tiny: "2.0.0.1", dev: "2.0.0.dev3" },
    }

    transitions.each do |from, bumps|
      bumps.each do |segment, to|
        it "bumps #{from} to #{to} for #{segment}" do
          expect(version(from).bump(segment).value).to eq(to)
        end

        it "moves #{from} strictly forward under Gem::Version ordering for #{segment}" do
          expect(Gem::Version.new(version(from).bump(segment).value)).to be > Gem::Version.new(from)
        end
      end
    end

    it "bumps patch by default" do
      expect(version("1.2.3").bump.value).to eq("1.2.4")
    end

    it "accepts segment as a string" do
      expect(version("1.0.0").bump("minor").value).to eq("1.1.0")
    end

    it "raises for an unknown segment" do
      expect { version("1.0.0").bump(:hotfix) }.to raise_error(ArgumentError, /unknown segment/i)
    end

    it "raises for a two-integer version" do
      expect { version("1.2").bump }.to raise_error(ArgumentError, /cannot parse/i)
    end

    it "raises for a non-dev prerelease version" do
      expect { version("1.2.3.beta1").bump }.to raise_error(ArgumentError, /cannot parse/i)
    end
  end

  describe "#next_version" do
    it "finalizes a dev version to its target" do
      expect(version("0.0.4.dev3").next_version.value).to eq("0.0.4")
    end

    it "bumps the patch of a release version" do
      expect(version("1.0.99").next_version.value).to eq("1.0.100")
    end
  end
end
