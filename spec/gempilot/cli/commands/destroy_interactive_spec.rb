require "spec_helper"
require "stringio"

RSpec.describe Gempilot::CLI::Commands::Destroy do
  include FileUtils

  before do
    mkdir_p("lib/my_gem")
    mkdir_p("test")
    File.write("my_gem.gemspec", 'Gem::Specification.new { |s| s.name = "my_gem" }')
  end

  def destroy(keystrokes) = described_class.new(stdin: StringIO.new(keystrokes)).main([])

  describe "interactive mode" do
    context "when destroying a class" do
      before do
        mkdir_p("lib/my_gem/services")
        File.write("lib/my_gem/services/auth.rb", "# class")
      end

      it "prepends the gem namespace to a bare name", :aggregate_failures do
        expect { destroy("1\nServices::Auth\n") }.to output(a_string_including("class:")).to_stdout
        expect(File).not_to exist("lib/my_gem/services/auth.rb")
      end

      it "does not double the namespace when the full constant is given" do
        destroy("1\nMyGem::Services::Auth\n")

        expect(File).not_to exist("lib/my_gem/services/auth.rb")
      end

      it "drops the old hint and label" do
        expect { destroy("1\nServices::Auth\n") }.not_to output(/Fully-qualified|Constant/).to_stdout
      end
    end

    context "when destroying a module" do
      before { File.write("lib/my_gem/middleware.rb", "# module") }

      it "removes the module under the gem namespace" do
        destroy("2\nMiddleware\n")

        expect(File).not_to exist("lib/my_gem/middleware.rb")
      end
    end

    context "when destroying a command" do
      before do
        mkdir_p("lib/my_gem/cli/commands")
        File.write("lib/my_gem/cli/commands/deploy.rb", "# command")
      end

      it "uses the type label and does not namespace the command", :aggregate_failures do
        expect { destroy("3\ndeploy\n") }.to output(a_string_including("command:")).to_stdout
        expect(File).not_to exist("lib/my_gem/cli/commands/deploy.rb")
      end
    end

    context "when the gem name is hyphenated (multi-segment module)" do
      before do
        rm_f("my_gem.gemspec")
        rm_rf("lib/my_gem")
        File.write("my-gem.gemspec", 'Gem::Specification.new { |s| s.name = "my-gem" }')
        mkdir_p("lib/my")
        File.write("lib/my/widget.rb", "# class")
      end

      it "does not double the root segment when resolving partially-qualified input" do
        destroy("1\nMy::Widget\n")

        expect(File).not_to exist("lib/my/widget.rb")
      end

      it "removes the generated test file at the non-duplicated path" do
        mkdir_p("test/my/gem")
        File.write("test/my/gem/gadget_test.rb", "# test")

        destroy("1\nGadget\n")

        expect(File).not_to exist("test/my/gem/gadget_test.rb")
      end
    end
  end
end
