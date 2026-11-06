require "spec_helper"

# Runs the real rbs CLI inside a minimal gem whose only dependency is rbs.
RSpec.describe Gempilot::RBSTask do
  let(:rbs_task) { described_class.new(root: Dir.pwd) }

  around do |example|
    old_app = Rake.application
    begin
      Rake.application = Rake::Application.new
      Dir.mktmpdir("rbs_task_spec") do |tmpdir|
        Dir.chdir(tmpdir) { Bundler.with_unbundled_env { example.run } }
      end
    ensure
      Rake.application = old_app
    end
  end

  def write_gem
    File.write("Gemfile", %(source "https://rubygems.org"\ngem "rbs"\n))
    system("bundle", "lock", "--local", out: File::NULL, exception: true)
  end

  def write_sig(source)
    FileUtils.mkdir_p("sig")
    File.write("sig/my_gem.rbs", source)
  end

  def invoke(name)
    Rake::Task[name].invoke
  end

  before do
    write_gem
    rbs_task
  end

  describe "task definitions" do
    %w[
      rbs:setup rbs:clobber rbs:validate
      rbs:collection:init rbs:collection:install rbs:collection:update
    ].each do |name|
      it "defines #{name}" do
        expect(Rake::Task).to be_task_defined(name)
      end
    end
  end

  describe "setup" do
    it "installs the collection" do
      invoke("setup")
      expect(Pathname(".gem_rbs_collection")).to be_directory
    end

    context "when setup is already described" do
      let(:rbs_task) do
        Rake::Task.define_task(:setup).add_description("Prepare everything")
        described_class.new(root: Dir.pwd)
      end

      it "keeps the existing description" do
        expect(Rake::Task["setup"].comment).to eq("Prepare everything")
      end
    end
  end

  describe "clobber" do
    it "removes the installed collection" do
      invoke("rbs:setup")
      invoke("clobber")
      expect(Pathname(".gem_rbs_collection")).not_to exist
    end
  end

  describe "rbs:setup" do
    it "installs the collection" do
      invoke("rbs:setup")
      expect(Pathname(".gem_rbs_collection")).to be_directory
    end

    it "pins the collection" do
      invoke("rbs:setup")
      expect(Pathname("rbs_collection.lock.yaml")).to be_file
    end
  end

  describe "rbs:clobber" do
    it "removes the installed collection" do
      invoke("rbs:setup")
      invoke("rbs:clobber")
      expect(Pathname(".gem_rbs_collection")).not_to exist
    end
  end

  describe "rbs:collection:init" do
    it "writes rbs_collection.yaml when it is missing" do
      invoke("rbs:collection:init")
      expect(Pathname("rbs_collection.yaml")).to be_file
    end

    it "leaves an existing rbs_collection.yaml alone" do
      File.write("rbs_collection.yaml", "path: .gem_rbs_collection\n")
      invoke("rbs:collection:init")
      expect(File.read("rbs_collection.yaml")).to eq("path: .gem_rbs_collection\n")
    end
  end

  describe "rbs:collection:install" do
    it "installs the collection" do
      invoke("rbs:collection:install")
      expect(Pathname(".gem_rbs_collection")).to be_directory
    end
  end

  describe "rbs:collection:update" do
    before do
      invoke("rbs:collection:init")
      FileUtils.rm_f("rbs_collection.lock.yaml")
    end

    it "writes the lockfile" do
      invoke("rbs:collection:update")
      expect(Pathname("rbs_collection.lock.yaml")).to be_file
    end
  end

  describe "rbs:validate" do
    it "passes for signatures that resolve" do
      write_sig("module MyGem\n  def self.name: () -> String\nend\n")
      expect { invoke("rbs:validate") }.not_to raise_error
    end

    it "fails for a signature naming an unknown type" do
      write_sig("module MyGem\n  def self.name: () -> NoSuchType\nend\n")
      expect { invoke("rbs:validate") }.to raise_error(RuntimeError, /rbs -I sig validate/)
    end
  end
end
