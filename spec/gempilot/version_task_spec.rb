require "spec_helper"

RSpec.describe Gempilot::VersionTask do
  around do |example|
    old_app = Rake.application
    Rake.application = Rake::Application.new
    Dir.mktmpdir("version_task_spec") do |tmpdir|
      Dir.chdir(tmpdir) { example.run }
    end
  ensure
    Rake.application = old_app
  end

  before do
    system("git init --quiet .")
    system("git config user.email 'test@test.com'")
    system("git config user.name 'Test'")
    File.write("my_gem.gemspec", 'Gem::Specification.new { |s| s.name = "my_gem" }')
    FileUtils.mkdir_p("lib/my_gem")
    File.write("lib/my_gem.rb", "module MyGem; end\n")
    File.write("lib/my_gem/version.rb", <<~RUBY)
      module MyGem
        VERSION = "1.0.0.dev3".freeze
      end
    RUBY
    system("git add . && git commit -m 'Initial commit' --quiet")
    described_class.new(root: Dir.pwd)
  end

  def version_in_file
    File.read("lib/my_gem/version.rb")[/VERSION = "([^"]+)"/, 1]
  end

  describe "version:bump" do
    it "bumps patch by default" do
      Rake::Task["version:bump"].invoke
      expect(version_in_file).to eq("1.0.1")
    end

    it "forwards the segment argument" do
      Rake::Task["version:bump"].invoke("dev")
      expect(version_in_file).to eq("1.0.0.dev4")
    end
  end

  describe "version:release" do
    it "forwards the segment argument to version:bump" do
      Rake::Task["version:release"].invoke("dev")
      expect(version_in_file).to eq("1.0.0.dev4")
    end

    it "commits and tags after bumping", :aggregate_failures do
      Rake::Task["version:release"].invoke("dev")
      expect(`git log -1 --pretty=%B`.strip).to eq("Bump version to 1.0.0.dev4")
      expect(`git tag`.strip).to eq("v1.0.0.dev4")
    end
  end

  describe "release task hierarchy" do
    it "defines the release and unrelease tasks", :aggregate_failures do
      %w[release release:rubygems release:github release:list:github unrelease unrelease:github].each do |name|
        expect(Rake::Task).to be_task_defined(name)
      end
    end

    it "removes the old version:github tasks", :aggregate_failures do
      %w[version:github:release version:github:unrelease version:github:list].each do |name|
        expect(Rake::Task).not_to be_task_defined(name)
      end
    end

    it "composes release from the per-remote tasks" do
      expect(Rake::Task["release"].prerequisites).to eq(%w[release:rubygems release:github])
    end

    it "builds release:rubygems from bundler's own tasks" do
      chain = %w[build release:guard_clean release:source_control_push release:rubygem_push]
      expect(Rake::Task["release:rubygems"].prerequisites).to eq(chain)
    end

    it "composes unrelease from the github task" do
      expect(Rake::Task["unrelease"].prerequisites).to eq(%w[unrelease:github])
    end
  end

  describe "release task behavior" do
    let(:origin) { instance_double(Gempilot::Origin, push: nil) }
    let(:github) { instance_double(Gempilot::GithubRelease, create: nil, destroy: nil, list: nil) }

    before do
      allow(Gempilot::Origin).to receive(:new).and_return(origin)
      allow(Gempilot::GithubRelease).to receive(:new).and_return(github)
    end

    it "release:source_control_push pushes via Origin" do
      Rake::Task["release:source_control_push"].invoke
      expect(origin).to have_received(:push)
    end

    it "release:github pushes, then creates the release", :aggregate_failures do
      Rake::Task["release:github"].invoke
      expect(origin).to have_received(:push)
      expect(github).to have_received(:create)
    end

    it "release:list:github lists releases" do
      Rake::Task["release:list:github"].invoke
      expect(github).to have_received(:list)
    end

    it "unrelease:github destroys the release" do
      Rake::Task["unrelease:github"].invoke
      expect(github).to have_received(:destroy)
    end
  end
end
