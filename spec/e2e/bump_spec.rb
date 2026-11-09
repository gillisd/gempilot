require "spec_helper"

# Runs the installed gempilot bump inside a gem made by gempilot create.
# Needs network access.
RSpec.describe "gempilot bump", :integration do
  include E2EHelpers

  def version
    File.read("test_gem/lib/test_gem/version.rb")[/VERSION = "([^"]+)"/, 1]
  end

  before { create("test_gem") }

  it "bumps the patch version by default" do
    run("gempilot", "bump", chdir: "test_gem")
    expect(version).to eq("0.0.2")
  end

  it "bumps the given segment" do
    run("gempilot", "bump", "minor", chdir: "test_gem")
    expect(version).to eq("0.1.0")
  end

  it "fails for an unknown segment" do
    expect(run("gempilot", "bump", "hotfix", chdir: "test_gem")).not_to be_success
  end
end
