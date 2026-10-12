require "spec_helper"
require "stringio"

RSpec.describe Gempilot::CLI::Generator, :tmpdir do
  let(:gem_templates) { File.join(Gempilot::ROOT, "data", "templates", "gem") }
  let(:stdout) { StringIO.new }
  let(:generator) { generator_class.new(stdout:) }
  let(:generator_class) do
    templates = gem_templates
    stub_const("TemplateGenerator", Class.new(Gempilot::CLI::Command))
      .tap { it.include(described_class) }
      .tap { it.template_dir(templates) }
  end

  describe "#template_dir" do
    it "exposes the configured template directory" do
      expect(generator.template_dir).to eq(gem_templates)
    end
  end

  describe "#mkdir" do
    before { generator.mkdir("new_dir") }

    it "creates the directory" do
      expect(Pathname("new_dir")).to be_directory
    end

    it "prints the action" do
      expect(stdout.string).to include("mkdir")
    end
  end

  describe "#touch" do
    it "creates the file" do
      generator.touch("new_file")
      expect(File).to exist("new_file")
    end
  end

  describe "#cp" do
    before { generator.cp("dotfiles/rubocop.yml.erb", ".rubocop.yml") }

    it "copies the template into place" do
      expect(File).to exist(".rubocop.yml")
    end

    it "copies the template content" do
      expect(File.read(".rubocop.yml")).not_to be_empty
    end
  end

  describe "#erb" do
    let(:rendered) { File.read("version.rb") }

    before do
      generator.instance_variable_set(:@gem_name, "test_gem")
      generator.instance_variable_set(:@module_name, "TestGem")
      generator.instance_variable_set(:@module_parts, ["TestGem"])
      generator.instance_variable_set(:@ruby_version, "3.4.8")
      generator.erb("lib/gem_name/version.rb.erb", "version.rb")
    end

    it "renders the module declaration" do
      expect(rendered).to include("module TestGem")
    end

    it "renders the initial version" do
      expect(rendered).to include('VERSION = "0.0.1"')
    end
  end

  describe "#chmod" do
    before { File.write("script", "#!/bin/sh\n") }

    it "changes the file permissions" do
      generator.chmod("+x", "script")
      expect(Pathname("script")).to be_executable
    end
  end

  describe "#sh" do
    it "returns the command success" do
      expect(generator.sh("true")).to be(true)
    end
  end

  describe "#create_file" do
    it "writes the content" do
      generator.create_file("output.rb", "# hello\n")
      expect(File.read("output.rb")).to eq("# hello\n")
    end
  end
end
