require "spec_helper"
require "open3"

RSpec.describe Gempilot::CLI::Commands::Create do
  subject(:command) { described_class.new }

  def create(name, *flags)
    command.main([
                   "--author", "Test Author", "--email", "test@example.com",
                   "--summary", "A test gem", "--ruby-version", "3.4.8",
                   "--test", "minitest", "--no-exe", "--no-git", *flags, name
                 ])
  end

  def gem_names
    gem_lines = File.readlines("test_gem/Gemfile").select { |line| line.start_with?('gem "') }
    gem_lines.map { |line| line[/gem "([^"]+)"/, 1] }
  end

  describe "gem layout" do
    before { allow(command).to receive(:sh) }

    context "with the default options" do
      before { create("test_gem") }

      it "creates the gem root directory" do
        expect(Dir).to exist("test_gem")
      end

      it "creates the library directory" do
        expect(Dir).to exist("test_gem/lib")
      end

      it "creates the namespace directory" do
        expect(Dir).to exist("test_gem/lib/test_gem")
      end

      it "creates the test directory" do
        expect(Dir).to exist("test_gem/test")
      end

      it "creates the binstub directory" do
        expect(Dir).to exist("test_gem/bin")
      end

      it "makes the console script executable" do
        expect(File).to be_executable("test_gem/bin/console")
      end

      it "makes the setup script executable" do
        expect(File).to be_executable("test_gem/bin/setup")
      end

      it "creates the rubocop config" do
        expect(File).to exist("test_gem/.rubocop.yml")
      end

      it "creates the git ignore file" do
        expect(File).to exist("test_gem/.gitignore")
      end

      it "creates the ruby version file" do
        expect(File).to exist("test_gem/.ruby-version")
      end

      it "creates the zeitwerk test" do
        expect(File).to exist("test_gem/test/zeitwerk_test.rb")
      end

      it "creates the CI workflow" do
        expect(File).to exist("test_gem/.github/workflows/ci.yml")
      end

      it "skips the rakelib directory" do
        expect(Dir).not_to exist("test_gem/rakelib")
      end

      it "skips the version rake file" do
        expect(File).not_to exist("test_gem/rakelib/version.rake")
      end
    end

    context "with the exe flag" do
      before { create("test_gem", "--exe") }

      it "creates the executable directory" do
        expect(Dir).to exist("test_gem/exe")
      end

      it "creates the executable" do
        expect(File).to exist("test_gem/exe/test_gem")
      end

      it "marks the executable runnable" do
        expect(File).to be_executable("test_gem/exe/test_gem")
      end
    end

    context "with the rspec framework" do
      before { create("test_gem", "--test", "rspec") }

      it "creates the spec directory" do
        expect(Dir).to exist("test_gem/spec")
      end

      it "omits the test directory" do
        expect(Dir).not_to exist("test_gem/test")
      end

      it "creates the spec helper" do
        expect(File).to exist("test_gem/spec/spec_helper.rb")
      end

      it "creates the gem spec file" do
        expect(File).to exist("test_gem/spec/test_gem_spec.rb")
      end

      it "creates the rspec options file" do
        expect(File).to exist("test_gem/.rspec")
      end

      it "creates the zeitwerk spec" do
        expect(File).to exist("test_gem/spec/zeitwerk_spec.rb")
      end
    end

    context "with a hyphenated gem name" do
      before { create("gempilot-encryption") }

      it "creates the base namespace directory" do
        expect(Dir).to exist("gempilot-encryption/lib/gempilot")
      end

      it "creates the nested namespace directory" do
        expect(Dir).to exist("gempilot-encryption/lib/gempilot/encryption")
      end

      it "creates the nested entry file" do
        expect(File).to exist("gempilot-encryption/lib/gempilot/encryption.rb")
      end

      it "creates the nested version file" do
        expect(File).to exist("gempilot-encryption/lib/gempilot/encryption/version.rb")
      end
    end
  end

  describe "generated gemspec" do
    before { allow(command).to receive(:sh) }

    context "with the default options" do
      let(:gemspec) { File.read("test_gem/test_gem.gemspec") }

      before { create("test_gem") }

      it "names the gem" do
        expect(gemspec).to include('spec.name = "test_gem"')
      end

      it "reads the version constant" do
        expect(gemspec).to include("TestGem::VERSION")
      end

      it "lists the author" do
        expect(gemspec).to include('"Test Author"')
      end

      it "lists the email" do
        expect(gemspec).to include('"test@example.com"')
      end

      it "carries the summary" do
        expect(gemspec).to include('"A test gem"')
      end

      it "leaves no placeholder markers" do
        expect(gemspec).not_to include("TODO")
      end

      it "invokes git" do
        expect(gemspec).to include("git")
      end

      it "lists tracked files" do
        expect(gemspec).to include("ls-files")
      end

      it "reads the file list through a pipe" do
        expect(gemspec).to include("IO.popen")
      end

      it "globs files as a fallback" do
        expect(gemspec).to include("Dir.glob")
      end

      it "falls back on an empty file list" do
        expect(gemspec).to include("files.empty?")
      end

      it "has no leading blank line" do
        expect(gemspec).not_to start_with("\n")
      end
    end

    context "with the rspec framework" do
      before { create("test_gem", "--test", "rspec") }

      it "has no leading blank line" do
        expect(File.read("test_gem/test_gem.gemspec")).not_to start_with("\n")
      end
    end

    context "with a hyphenated gem name" do
      let(:gemspec) { File.read("gempilot-encryption/gempilot-encryption.gemspec") }

      before { create("gempilot-encryption") }

      it "requires the nested version file" do
        expect(gemspec).to include('require_relative "lib/gempilot/encryption/version"')
      end

      it "reads the nested version constant" do
        expect(gemspec).to include("Gempilot::Encryption::VERSION")
      end
    end
  end

  describe "generated entry file" do
    before { allow(command).to receive(:sh) }

    context "with the default options" do
      let(:entry) { File.read("test_gem/lib/test_gem.rb") }

      before { create("test_gem") }

      it "declares the gem module" do
        expect(entry).to include("module TestGem")
      end

      it "has no leading blank line" do
        expect(entry).not_to start_with("\n")
      end
    end

    context "with the rspec framework" do
      before { create("test_gem", "--test", "rspec") }

      it "has no leading blank line" do
        expect(File.read("test_gem/lib/test_gem.rb")).not_to start_with("\n")
      end
    end
  end

  describe "generated version file" do
    before { allow(command).to receive(:sh) }

    context "with the default options" do
      let(:version_rb) { File.read("test_gem/lib/test_gem/version.rb") }

      before { create("test_gem") }

      it "declares the gem module" do
        expect(version_rb).to include("module TestGem")
      end

      it "starts the version at the first patch" do
        expect(version_rb).to include('VERSION = "0.0.1"')
      end

      it "freezes the version constant" do
        expect(version_rb).to include(".freeze")
      end

      it "declares a single module" do
        expect(version_rb.scan(/^ *module /).size).to eq(1)
      end

      it "has no leading blank line" do
        expect(version_rb).not_to start_with("\n")
      end
    end

    context "with a multi word gem name" do
      before { create("my_cool_gem") }

      it "camelizes the module name" do
        expect(File.read("my_cool_gem/lib/my_cool_gem/version.rb")).to include("module MyCoolGem")
      end
    end

    context "with a hyphenated gem name" do
      let(:version_rb) { File.read("gempilot-encryption/lib/gempilot/encryption/version.rb") }

      before { create("gempilot-encryption") }

      it "declares the base module" do
        expect(version_rb).to include("module Gempilot")
      end

      it "declares the nested module" do
        expect(version_rb).to include("module Encryption")
      end

      it "defines the version constant" do
        expect(version_rb).to include("VERSION")
      end
    end
  end

  describe "generated gem test" do
    before { allow(command).to receive(:sh) }

    context "with the default options" do
      let(:test_file) { File.read("test_gem/test/test_gem_test.rb") }

      before { create("test_gem") }

      it "defines a minitest case" do
        expect(test_file).to include("class TestGemTest < Minitest::Test")
      end

      it "checks the version constant" do
        expect(test_file).to include("TestGem::VERSION")
      end

      it "has no leading blank line" do
        expect(test_file).not_to start_with("\n")
      end
    end

    context "with the rspec framework" do
      let(:spec_file) { File.read("test_gem/spec/test_gem_spec.rb") }

      before { create("test_gem", "--test", "rspec") }

      it "describes the gem module" do
        expect(spec_file).to include("RSpec.describe TestGem")
      end

      it "checks the version constant" do
        expect(spec_file).to include("TestGem::VERSION")
      end
    end

    context "with a hyphenated gem name" do
      before { create("gempilot-encryption") }

      it "checks the nested version constant" do
        content = File.read("gempilot-encryption/test/gempilot_encryption_test.rb")
        expect(content).to include("Gempilot::Encryption::VERSION")
      end
    end
  end

  describe "generated zeitwerk check" do
    before { allow(command).to receive(:sh) }

    context "with the default options" do
      let(:zeitwerk_test) { File.read("test_gem/test/zeitwerk_test.rb") }

      before { create("test_gem") }

      it "defines a minitest case" do
        expect(zeitwerk_test).to include("class ZeitwerkTest < Minitest::Test")
      end

      it "eager loads the gem" do
        expect(zeitwerk_test).to include("TestGem::LOADER.eager_load(force: true)")
      end
    end

    context "with the rspec framework" do
      let(:zeitwerk_spec) { File.read("test_gem/spec/zeitwerk_spec.rb") }

      before { create("test_gem", "--test", "rspec") }

      it "describes zeitwerk" do
        expect(zeitwerk_spec).to include('RSpec.describe "Zeitwerk"')
      end

      it "eager loads the gem" do
        expect(zeitwerk_spec).to include("TestGem::LOADER.eager_load(force: true)")
      end
    end

    context "with a hyphenated gem name" do
      before { create("gempilot-encryption") }

      it "eager loads the nested module" do
        content = File.read("gempilot-encryption/test/zeitwerk_test.rb")
        expect(content).to include("Gempilot::Encryption::LOADER")
      end
    end
  end

  describe "generated Gemfile" do
    let(:gemfile) { File.read("test_gem/Gemfile") }

    before { allow(command).to receive(:sh) }

    context "with the default options" do
      before { create("test_gem") }

      it "depends on gempilot" do
        expect(gemfile).to include('gem "gempilot"')
      end

      it "omits the warning gem" do
        expect(gemfile).not_to include('gem "warning"')
      end

      it "orders gems alphabetically" do
        expect(gem_names).to eq(gem_names.sort)
      end
    end

    context "with the rspec framework" do
      before { create("test_gem", "--test", "rspec") }

      it "depends on rspec" do
        expect(gemfile).to include('gem "rspec"')
      end

      it "depends on gempilot" do
        expect(gemfile).to include('gem "gempilot"')
      end

      it "omits minitest" do
        expect(gemfile).not_to include('gem "minitest"')
      end

      it "orders gems alphabetically" do
        expect(gem_names).to eq(gem_names.sort)
      end
    end
  end

  describe "generated console script" do
    before { allow(command).to receive(:sh) }

    context "with a hyphenated gem name" do
      before { create("gempilot-encryption") }

      it "requires the nested path" do
        expect(File.read("gempilot-encryption/bin/console")).to include('require "gempilot/encryption"')
      end
    end
  end

  describe "generated CI workflow" do
    let(:workflow) { File.read("test_gem/.github/workflows/ci.yml") }

    before { allow(command).to receive(:sh) }

    context "with the default options" do
      before { create("test_gem") }

      it "runs the test task" do
        expect(workflow).to include("bundle exec rake test")
      end

      it "runs the rubocop task" do
        expect(workflow).to include("bundle exec rake rubocop")
      end
    end

    context "with the rspec framework" do
      before { create("test_gem", "--test", "rspec") }

      it "runs the spec task" do
        expect(workflow).to include("bundle exec rake spec")
      end

      it "skips the test task" do
        expect(workflow).not_to include("bundle exec rake test")
      end
    end
  end

  describe "bundle install" do
    let(:system_calls) { [] }
    let(:bundle_call) { system_calls.find { |call| call[:command].first == "bundle" } }

    before do
      allow(command).to receive(:system) do |*args|
        system_calls << { command: args, bundle_gemfile: ENV.fetch("BUNDLE_GEMFILE", nil) }
        true
      end
      create("test_gem")
    end

    it "runs through the system shell" do
      expect(bundle_call).not_to be_nil
    end

    it "runs outside the parent bundle" do
      expect(bundle_call[:bundle_gemfile]).to be_nil
    end
  end

  describe "author defaults" do
    context "without a git identity" do
      let(:probe_env) do
        {
          "HOME" => "/nonexistent",
          "GIT_CONFIG_NOSYSTEM" => "1",
          "GIT_CONFIG_GLOBAL" => "/nonexistent",
          "BUNDLE_GEMFILE" => Gempilot::ROOT.join("Gemfile").to_s,
          "GEM_HOME" => Gem.default_dir,
          "GEM_PATH" => Gem.path.join(File::PATH_SEPARATOR),
        }
      end
      let(:probe_script) do
        <<~RUBY
          require "bundler/setup"
          require "gempilot"
          cmd = Gempilot::CLI::Commands::Create.new
          puts cmd.options[:author].inspect
          puts cmd.options[:email].inspect
        RUBY
      end
      let(:probe) { Open3.capture2(probe_env, RbConfig.ruby, "-e", probe_script, err: File::NULL) }

      it "loads the command cleanly" do
        expect(probe.last).to be_success
      end

      it "leaves the author blank" do
        expect(["\"\"", "nil"]).to include(probe.first.lines.first.strip)
      end
    end
  end

  describe "generated default rake task" do
    def scaffold(name)
      command.main([
                     "--author", "Test Author", "--email", "test@example.com",
                     "--summary", "A test gem", "--ruby-version", RUBY_VERSION,
                     "--test", "minitest", "--no-exe", "--no-git", name
                   ])
      localize_gempilot("#{name}/Gemfile")
    end

    def localize_gempilot(gemfile)
      local = %(gem "gempilot", path: #{Gempilot::ROOT.to_s.inspect}, require: false)
      File.write(gemfile, File.read(gemfile).sub(/^gem "gempilot".*$/, local))
    end

    def run_rake(dir)
      Bundler.with_unbundled_env do
        Open3.capture2e("bundle", "exec", "rake", chdir: dir)
      end
    end

    context "with a flat gem name" do
      before { scaffold("test_gem") }

      it "passes" do
        output, status = run_rake("test_gem")
        expect(status).to be_success, output
      end
    end

    context "with a hyphenated gem name" do
      before { scaffold("gempilot-encryption") }

      it "passes" do
        output, status = run_rake("gempilot-encryption")
        expect(status).to be_success, output
      end
    end
  end
end
