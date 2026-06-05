require "spec_helper"
require "tmpdir"
require "stringio"

RSpec.describe Gempilot::CLI::Commands::New do
  include FileUtils

  subject(:command) { described_class.new(stdout: StringIO.new) }

  around do |example|
    Dir.mktmpdir("new_command_spec") do |tmpdir|
      Dir.chdir(tmpdir) do
        mkdir_p("lib/my_gem")
        mkdir_p("test")
        File.write("my_gem.gemspec", 'Gem::Specification.new { |s| s.name = "my_gem" }')
        example.run
      end
    end
  end

  describe "command generation with namespaced input" do
    before { mkdir_p("lib/my_gem/cli/commands") }

    context "when name contains :: separators" do
      it "extracts the last segment as the command name" do
        command.main(["command", "MyGem::Command::Filter"])

        expect(File).to exist("lib/my_gem/cli/commands/filter.rb")
      end

      it "generates the correct class name" do
        command.main(["command", "MyGem::Command::Filter"])
        content = File.read("lib/my_gem/cli/commands/filter.rb")

        expect(content).to include("class Filter < Command")
      end
    end
  end
end
