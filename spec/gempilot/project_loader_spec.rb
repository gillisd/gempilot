require "spec_helper"

RSpec.describe Gempilot::ProjectLoader do
  around do |example|
    Dir.mktmpdir("project_loader_spec") { |dir| Dir.chdir(dir) { example.run } }
  end

  def register_loader(dir)
    FileUtils.mkdir_p(dir)
    Zeitwerk::Loader.new.tap do |loader|
      loader.push_dir(dir)
      yield loader if block_given?
      loader.setup
    end
  end

  describe "#loader" do
    let!(:loader) { register_loader("lib") }

    after { loader.unregister }

    it "returns the registered loader managing the directory" do
      expect(described_class.new("lib").loader).to be(loader)
    end

    it "resolves symlinks before comparing directories" do
      File.symlink("lib", "linked")
      expect(described_class.new("linked").loader).to be(loader)
    end

    it "raises NotFound when no loader manages the directory" do
      FileUtils.mkdir_p("other")
      expect { described_class.new("other").loader }.to raise_error(described_class::NotFound, /other/)
    end
  end

  describe "#loader for an inflected namespace" do
    let!(:loader) do
      register_loader("lib") do |l|
        File.write("lib/ecs.rb", "module ECS; end\n")
        l.inflector.inflect("ecs" => "ECS")
      end
    end

    after { loader.unregister }

    it "hands back the loader carrying the project's own inflections" do
      found = described_class.new("lib").loader
      expect(found.cpath_expected_at("lib/ecs.rb")).to eq("ECS")
    end
  end
end
