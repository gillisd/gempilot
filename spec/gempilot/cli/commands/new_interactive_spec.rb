require "spec_helper"
require "tmpdir"
require "stringio"

RSpec.describe Gempilot::CLI::Commands::New do
  include FileUtils

  around do |example|
    Dir.mktmpdir("new_interactive_spec") do |tmpdir|
      Dir.chdir(tmpdir) do
        mkdir_p("lib/my_gem")
        mkdir_p("test")
        File.write("my_gem.gemspec", 'Gem::Specification.new { |s| s.name = "my_gem" }')
        example.run
      end
    end
  end

  # Runs `new` with no arguments (interactive mode), feeding +keystrokes+ to
  # stdin, and returns everything written to stdout.
  def generate(keystrokes)
    out = StringIO.new
    described_class.new(stdin: StringIO.new(keystrokes), stdout: out).main([])
    out.string
  end

  describe "interactive mode" do
    context "when generating a class" do
      it "prepends the gem namespace to a bare name", :aggregate_failures do
        output = generate("1\nServices::Auth\n")

        expect(output).to include("class:")
        expect(File).to exist("lib/my_gem/services/auth.rb")
        expect(File.read("lib/my_gem/services/auth.rb")).to include("class Auth")
      end

      it "does not double the namespace when the full constant is given" do
        generate("1\nMyGem::Services::Auth\n")

        expect(File).to exist("lib/my_gem/services/auth.rb")
      end

      it "drops the old hint and label", :aggregate_failures do
        output = generate("1\nServices::Auth\n")

        expect(output).not_to include("Fully-qualified")
        expect(output).not_to include("Constant")
      end
    end

    context "when generating a module" do
      it "writes the module under the gem namespace", :aggregate_failures do
        generate("2\nMiddleware\n")

        expect(File).to exist("lib/my_gem/middleware.rb")
        expect(File.read("lib/my_gem/middleware.rb")).to include("module Middleware")
      end
    end

    context "when generating a command" do
      before { mkdir_p("lib/my_gem/cli/commands") }

      it "uses the type label and does not namespace the command", :aggregate_failures do
        output = generate("3\ndeploy\n")

        expect(output).to include("command:")
        expect(File).to exist("lib/my_gem/cli/commands/deploy.rb")
        expect(File.read("lib/my_gem/cli/commands/deploy.rb")).to include("class Deploy < Command")
      end
    end

    context "when a spec/ directory exists but there is no rspec config" do
      before { mkdir_p("spec") }

      it "still scaffolds a minitest test file" do
        generate("1\nServices::Auth\n")

        expect(File).to exist("test/my_gem/services/auth_test.rb")
      end
    end

    context "when the gem name is hyphenated (multi-segment module)" do
      before do
        rm_f("my_gem.gemspec")
        rm_rf("lib/my_gem")
        File.write("my-gem.gemspec", 'Gem::Specification.new { |s| s.name = "my-gem" }')
        mkdir_p("lib/my/gem")
      end

      it "namespaces a bare name under the full module" do
        generate("1\nWidget\n")

        expect(File).to exist("lib/my/gem/widget.rb")
      end

      it "does not double the root segment for partially-qualified input", :aggregate_failures do
        generate("1\nMy::Widget\n")

        expect(File).not_to exist("lib/my/gem/my/widget.rb")
        expect(File).to exist("lib/my/widget.rb")
      end

      it "writes the generated test file at the non-duplicated path", :aggregate_failures do
        generate("1\nWidget\n")

        expect(File).to exist("test/my/gem/widget_test.rb")
        expect(File).not_to exist("test/my/gem/gem/widget_test.rb")
      end
    end
  end
end
