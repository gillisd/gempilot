require "spec_helper"

RSpec.describe Gempilot::RBSTask do
  let(:rbs_task) { described_class.new(root: Dir.pwd) }

  around do |example|
    old_app = Rake.application
    Rake.application = Rake::Application.new
    Dir.mktmpdir("rbs_task_spec") do |tmpdir|
      Dir.chdir(tmpdir) { example.run }
    end
  ensure
    Rake.application = old_app
  end

  describe "task definitions" do
    before { rbs_task }

    %w[
      rbs:setup rbs:clobber rbs:validate
      rbs:collection:init rbs:collection:install rbs:collection:update
    ].each do |name|
      it "defines #{name}" do
        expect(Rake::Task).to be_task_defined(name)
      end
    end
  end

  describe "rbs:setup" do
    it "installs the collection" do
      rbs_task
      expect(Rake::Task["rbs:setup"].prerequisites).to eq(["rbs:collection:install"])
    end
  end

  describe "setup" do
    it "sets up rbs" do
      rbs_task
      expect(Rake::Task["setup"].prerequisites).to include("rbs:setup")
    end

    it "keeps an existing description" do
      Rake::Task.define_task(:setup).add_description("Prepare everything")
      rbs_task
      expect(Rake::Task["setup"].comment).to eq("Prepare everything")
    end
  end

  describe "clobber" do
    it "clobbers rbs" do
      rbs_task
      expect(Rake::Task["clobber"].prerequisites).to include("rbs:clobber")
    end
  end

  describe "rbs:clobber" do
    it "removes the installed collection" do
      FileUtils.mkdir_p(".gem_rbs_collection/json")
      rbs_task
      Rake::Task["rbs:clobber"].invoke
      expect(File).not_to exist(".gem_rbs_collection")
    end
  end

  describe "rbs:validate" do
    before do
      File.write("rbs_collection.yaml", "gems: []\n")
      allow(rbs_task).to receive(:sh)
    end

    it "sets up rbs first" do
      expect(Rake::Task["rbs:validate"].prerequisites).to eq(["rbs:setup"])
    end

    it "runs rbs validate" do
      Rake::Task["rbs:validate"].invoke
      expect(rbs_task).to have_received(:sh).with("bundle", "exec", "rbs", "validate", chdir: Dir.pwd)
    end
  end

  describe "rbs:collection:init" do
    before { allow(rbs_task).to receive(:sh) }

    it "runs rbs collection init when rbs_collection.yaml is missing" do
      Rake::Task["rbs:collection:init"].invoke
      expect(rbs_task).to have_received(:sh).with("bundle", "exec", "rbs", "collection", "init", chdir: Dir.pwd)
    end

    it "leaves an existing rbs_collection.yaml alone" do
      File.write("rbs_collection.yaml", "gems: []\n")
      Rake::Task["rbs:collection:init"].invoke
      expect(rbs_task).not_to have_received(:sh)
    end
  end

  describe "rbs:collection:install" do
    before do
      File.write("rbs_collection.yaml", "gems: []\n")
      allow(rbs_task).to receive(:sh)
    end

    it "runs rbs collection install" do
      Rake::Task["rbs:collection:install"].invoke
      expect(rbs_task).to have_received(:sh).with("bundle", "exec", "rbs", "collection", "install", chdir: Dir.pwd)
    end
  end

  describe "rbs:collection:update" do
    before { allow(rbs_task).to receive(:sh) }

    it "runs rbs collection update" do
      Rake::Task["rbs:collection:update"].invoke
      expect(rbs_task).to have_received(:sh).with("bundle", "exec", "rbs", "collection", "update", chdir: Dir.pwd)
    end
  end
end
