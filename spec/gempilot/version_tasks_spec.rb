require "rake"
require "tmpdir"
require "gempilot/version_tasks"

RSpec.describe Gempilot::VersionTasks do
  around do |example|
    old_app = Rake.application
    Rake.application = Rake::Application.new
    Dir.mktmpdir("version_tasks_spec") do |tmpdir|
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
end
