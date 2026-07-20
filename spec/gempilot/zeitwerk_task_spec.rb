require "spec_helper"

RSpec.describe Gempilot::ZeitwerkTask do
  around do |example|
    old_app = Rake.application
    Rake.application = Rake::Application.new
    Dir.mktmpdir("zeitwerk_task_spec") do |tmpdir|
      Dir.chdir(tmpdir) { example.run }
    end
  ensure
    Rake.application = old_app
  end

  def write_gem
    FileUtils.mkdir_p("lib/my_gem")
    File.write("my_gem.gemspec", 'Gem::Specification.new { |s| s.name = "my_gem" }')
    File.write("lib/my_gem.rb", <<~RUBY)
      require "zeitwerk"
      module MyGem
        LOADER = Zeitwerk::Loader.for_gem.tap(&:setup)
      end
    RUBY
    File.write("lib/my_gem/version.rb", <<~RUBY)
      module MyGem
        VERSION = "1.0.0".freeze
      end
    RUBY
  end

  before do
    write_gem
    described_class.new(root: Dir.pwd)
  end

  describe "task definitions" do
    it "defines zeitwerk:validate" do
      expect(Rake::Task).to be_task_defined("zeitwerk:validate")
    end

    it "defines zeitwerk:all" do
      expect(Rake::Task).to be_task_defined("zeitwerk:all")
    end
  end

  describe "zeitwerk:validate" do
    it "passes for a conventionally-named gem" do
      expect { Rake::Task["zeitwerk:validate"].invoke }.not_to raise_error
    end

    context "when a file breaks the naming convention" do
      before { File.write("lib/my_gem/oops.rb", "module MyGem; class Correct; end; end\n") }

      it "fails" do
        expect { Rake::Task["zeitwerk:validate"].invoke }.to raise_error(RuntimeError)
      end
    end
  end

  describe "zeitwerk:all" do
    it "runs for a conventionally-named gem" do
      expect { Rake::Task["zeitwerk:all"].invoke }.not_to raise_error
    end
  end
end
