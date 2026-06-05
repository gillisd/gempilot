require "spec_helper"
require "tmpdir"
require "stringio"

RSpec.describe Gempilot::CLI::Commands::Destroy do
  include FileUtils

  subject(:command) { described_class.new(stdout: StringIO.new) }

  around do |example|
    Dir.mktmpdir("destroy_command_spec") do |tmpdir|
      Dir.chdir(tmpdir) do
        mkdir_p("lib/my_gem")
        mkdir_p("test")
        File.write("my_gem.gemspec", 'Gem::Specification.new { |s| s.name = "my_gem" }')
        example.run
      end
    end
  end

  describe "command destruction with namespaced input" do
    context "when name contains :: separators" do
      before do
        mkdir_p("lib/my_gem/cli/commands")
        File.write("lib/my_gem/cli/commands/filter.rb", "# command")
        mkdir_p("test/my_gem/cli/commands")
        File.write("test/my_gem/cli/commands/filter_test.rb", "# test")
      end

      it "removes the command file matching the last segment" do
        command.main(["command", "MyGem::Command::Filter"])

        expect(File).not_to exist("lib/my_gem/cli/commands/filter.rb")
      end

      it "removes the test file matching the last segment" do
        command.main(["command", "MyGem::Command::Filter"])

        expect(File).not_to exist("test/my_gem/cli/commands/filter_test.rb")
      end
    end
  end
end
