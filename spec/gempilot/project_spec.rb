require "spec_helper"

RSpec.describe Gempilot::Project do
  include FileUtils

  subject(:project) { described_class.new(Dir.pwd) }

  def in_tempdir
    Dir.mktmpdir("project_spec") do |tmpdir|
      chdir tmpdir do
        yield tmpdir
      end
    end
  end

  shared_examples "a gem project" do
    describe "#name" do
      it "derives the gem name from the lib layout" do
        expect(project.name).to eq(expected_name)
      end
    end

    describe "#require_path" do
      it "joins the lib segments with slashes" do
        expect(project.require_path).to eq(expected_require_path)
      end
    end

    describe "#autoload_root" do
      it "is the directory the gem's Zeitwerk loader manages" do
        expect(project.autoload_root.to_s).to end_with(expected_autoload_root)
      end
    end

    describe "#version" do
      it "reads the version value from version.rb" do
        expect(project.version.value).to eq("1.2.3")
      end

      it "points at the version.rb file" do
        expect(project.version.path.to_s).to end_with(version_file)
      end

      it "does not define the gem's modules in the real namespace" do
        project.version
        expect(Object).not_to be_const_defined(root_constant)
      end
    end

    describe "#refresh_version!" do
      it "re-reads the version from disk after a file change" do
        project.version
        File.write(version_file, File.read(version_file).sub("1.2.3", "1.2.4"))
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
        expect(File.read(version_file)).to include("1.2.4")
      end
    end
  end

  describe "a regular gem" do
    let(:expected_name) { "my_gem" }
    let(:expected_require_path) { "my_gem" }
    let(:expected_autoload_root) { "/lib" }
    let(:root_constant) { :MyGem }
    let(:version_file) { "lib/my_gem/version.rb" }

    around do |example|
      in_tempdir do
        Pathname("lib/my_gem").mkpath
        File.write "lib/my_gem.rb", "module MyGem; end\n"
        File.write version_file, <<~RUBY
          module MyGem
            VERSION = "1.2.3".freeze
          end
        RUBY
        example.run
      end
    end

    it_behaves_like "a gem project"

    context "when lib has a .rb file with no matching gem directory" do
      before do
        rm_rf("lib/my_gem")
        rm("lib/my_gem.rb")
        File.write("lib/standalone.rb", "# no matching dir\n")
      end

      it "raises ProjectIntrospectionError" do
        expect { project.name }.to raise_error(Gempilot::Project::ProjectIntrospectionError)
      end
    end

    context "when lib has more than one candidate gem" do
      before do
        Pathname("lib/other").mkpath
        File.write("lib/other.rb", "module Other; end\n")
      end

      it "raises ProjectIntrospectionError naming the ambiguity" do
        expect { project.name }
          .to raise_error(Gempilot::Project::ProjectIntrospectionError, /more than one/)
      end
    end

    context "when version.rb defines no VERSION constant" do
      before { File.write(version_file, "module MyGem\nend\n") }

      it "raises ProjectIntrospectionError naming the file" do
        expect { project.version }
          .to raise_error(Gempilot::Project::ProjectIntrospectionError, /VERSION constant/)
      end
    end
  end

  describe "a gem extension" do
    let(:expected_name) { "my_gem-extension" }
    let(:expected_require_path) { "my_gem/extension" }
    let(:expected_autoload_root) { "/lib/my_gem" }
    let(:root_constant) { :MyGem }
    let(:version_file) { "lib/my_gem/extension/version.rb" }

    around do |example|
      in_tempdir do
        Pathname("lib/my_gem/extension").mkpath
        File.write "lib/my_gem/extension.rb", <<~RUBY
          module MyGem
            module Extension
            end
          end
        RUBY
        File.write version_file, <<~RUBY
          module MyGem
            module Extension
              VERSION = "1.2.3".freeze
            end
          end
        RUBY
        example.run
      end
    end

    it_behaves_like "a gem project"
  end

  describe "a gem whose module name is inflected" do
    let(:version_file) { "lib/ecs/version.rb" }

    around do |example|
      in_tempdir do
        Pathname("lib/ecs").mkpath
        File.write "lib/ecs.rb", "module ECS; end\n"
        File.write version_file, "module ECS\n  VERSION = \"1.2.3\".freeze\nend\n"
        example.run
      end
    end

    it "reads the version without guessing the module name" do
      expect(project.version.value).to eq("1.2.3")
    end
  end
end
