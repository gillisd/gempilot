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

  def write_gem(name:, mod:, inflections: {})
    FileUtils.mkdir_p("lib/#{name}")
    File.write("#{name}.gemspec", %(Gem::Specification.new { |s| s.name = "#{name}" }))
    File.write("lib/#{name}.rb", <<~RUBY)
      require "zeitwerk"
      module #{mod}
        LOADER = Zeitwerk::Loader.for_gem.tap do |l|
          l.inflector.inflect(#{inflections.inspect})
          l.setup
        end
      end
    RUBY
    File.write("lib/#{name}/version.rb", "module #{mod}\n  VERSION = \"1.0.0\".freeze\nend\n")
  end

  describe "task definitions" do
    before do
      write_gem(name: "my_gem", mod: "MyGem")
      described_class.new(root: Dir.pwd)
    end

    it "defines zeitwerk:validate" do
      expect(Rake::Task).to be_task_defined("zeitwerk:validate")
    end

    it "defines zeitwerk:all" do
      expect(Rake::Task).to be_task_defined("zeitwerk:all")
    end
  end

  describe "zeitwerk:validate" do
    before do
      write_gem(name: "my_gem", mod: "MyGem")
      described_class.new(root: Dir.pwd)
    end

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
    before do
      write_gem(name: "my_gem", mod: "MyGem")
      described_class.new(root: Dir.pwd)
    end

    it "lists the constants the loader expects" do
      expect { Rake::Task["zeitwerk:all"].invoke }.to output(/MyGem::VERSION/).to_stdout_from_any_process
    end
  end

  describe "a gem whose loader inflects its module name" do
    before do
      write_gem(name: "ecs", mod: "ECS", inflections: { "ecs" => "ECS" })
      described_class.new(root: Dir.pwd)
    end

    it "validates through the gem's own loader" do
      expect { Rake::Task["zeitwerk:validate"].invoke }.not_to raise_error
    end

    it "lists constants under the inflected namespace" do
      expect { Rake::Task["zeitwerk:all"].invoke }.to output(/ECS::VERSION/).to_stdout_from_any_process
    end
  end
end
