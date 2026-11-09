require "spec_helper"

RSpec.describe Gempilot::Rubygems::Env do
  let(:exclude_control) { "ruby2_keywords" }
  let(:include_control) { "erb" }

  describe "loaded gems" do
    it "ensures this project contains the include control" do
      expect(Gem.loaded_specs).to include(include_control)
    end

    it "ensures this project does not contain the exclude control" do
      expect(Gem.loaded_specs).not_to include(exclude_control)
    end
  end

  describe "#all_default_gems" do
    let(:all_default_gem_names) do
      subject.all_default_gems.map(&:name)
    end

    it "includes a gem this project does use" do
      expect(all_default_gem_names).to include include_control
    end

    it "includes a gem this project does not use" do
      expect(all_default_gem_names).to include exclude_control
    end
  end

  describe "#default_gems" do
    let(:default_gem_names) do
      subject.default_gems.map(&:name)
    end

    it "includes a gem this project does use" do
      expect(default_gem_names).to include include_control
    end

    it "does not include a gem this project does not use" do
      expect(default_gem_names).not_to include exclude_control
    end
  end
end
