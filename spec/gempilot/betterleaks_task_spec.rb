require "spec_helper"
require "securerandom"

RSpec.describe Gempilot::BetterleaksTask do
  around do |example|
    old_app = Rake.application
    Rake.application = Rake::Application.new
    example.run
  ensure
    Rake.application = old_app
  end

  before { described_class.new }

  it "defines the betterleaks task" do
    expect(Rake::Task).to be_task_defined("betterleaks")
  end

  context "when betterleaks is not installed" do
    around do |example|
      original = ENV.fetch("PATH", nil)
      Dir.mktmpdir("empty_path") do |dir|
        ENV["PATH"] = dir
        example.run
      end
    ensure
      ENV["PATH"] = original
    end

    it "skips the scan without raising" do
      expect { Rake::Task["betterleaks"].invoke }.not_to raise_error
    end
  end

  describe "a real scan" do
    around { |example| Dir.mktmpdir("betterleaks_task_spec") { |dir| Dir.chdir(dir) { example.run } } }

    before { skip "betterleaks is not installed" unless system("betterleaks", "version", out: File::NULL) }

    def commit_file(name, content)
      system("git", "init", "--quiet", "-b", "main", ".")
      system("git", "config", "user.email", "test@test.com")
      system("git", "config", "user.name", "Test")
      File.write(name, content)
      system("git", "add", name)
      system("git", "commit", "--quiet", "-m", "Add #{name}")
    end

    it "passes on a history without secrets" do
      commit_file("app.rb", "puts 'hi'\n")
      expect { Rake::Task["betterleaks"].invoke }.not_to raise_error
    end

    it "fails when the history contains a secret" do
      commit_file("config.rb", %(github_token = "ghp_#{SecureRandom.alphanumeric(36)}"\n))
      expect { Rake::Task["betterleaks"].invoke }.to raise_error(RuntimeError, /betterleaks/)
    end

    it "scans the working tree when the gem is not a git repository" do
      File.write("app.rb", "puts 'hi'\n")
      expect { Rake::Task["betterleaks"].invoke }.not_to raise_error
    end
  end
end
