require "spec_helper"

RSpec.describe Gempilot::Project do
  include FileUtils

  around do |example|
    Dir.mktmpdir("project_spec") do |tmpdir|
      Dir.chdir(tmpdir) { example.run }
    end
  end

  before do
    mkdir_p("lib/my_gem")
    File.write("lib/my_gem.rb", "module MyGem; end\n")
    File.write("lib/my_gem/version.rb", "module MyGem\n  VERSION = \"1.2.3\".freeze\nend\n")
  end

  subject(:project) { described_class.new(Dir.pwd) }

  describe "#name" do
    it "discovers the gem name from the lib directory" do
      expect(project.name).to eq("my_gem")
    end
  end

  describe "#klass" do
    it "returns the gem module constant" do
      project.version
      expect(project.klass).to eq(MyGem)
    end
  end

  describe "#version" do
    it "returns a Gempilot::Project::Version with the correct value" do
      expect(project.version.value).to eq("1.2.3")
    end

    it "returns a Gempilot::Project::Version with the correct path" do
      expect(project.version.path.to_s).to end_with("lib/my_gem/version.rb")
    end
  end

  describe "#refresh_version!" do
    it "re-reads the version from disk after a file change" do
      project.version
      File.write("lib/my_gem/version.rb", "module MyGem\n  VERSION = \"1.2.4\".freeze\nend\n")
      project.refresh_version!
      expect(project.version.value).to eq("1.2.4")
    end
  end

  describe "#increment_version" do
    it "returns the next patch version" do
      expect(project.increment_version.value).to eq("1.2.4")
    end
  end

  describe "#write_version!" do
    it "replaces the old version string in the file" do
      old_version = project.version
      new_version = project.increment_version
      project.write_version!(old_version, new_version)
      content = File.read("lib/my_gem/version.rb")
      expect(content).to include("1.2.4")
    end
  end

  context "when lib directory has no gem subdirectory" do
    before do
      rm_rf("lib/my_gem")
      rm("lib/my_gem.rb")
      File.write("lib/standalone.rb", "# no matching dir\n")
    end

    it "raises ProjectIntrospectionError" do
      expect { project.name }.to raise_error(Gempilot::Project::ProjectIntrospectionError)
    end
  end

  describe "a gem extension" do

  end
end
