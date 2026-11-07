require "spec_helper"

RSpec.describe Gempilot::Shell do
  include FileUtils

  around do |example|
    Dir.mktmpdir("shell_spec") { |dir| Dir.chdir(dir) { example.run } }
  end

  def ruby_print(code)
    [RbConfig.ruby, "-e", "print #{code}"]
  end

  describe ".run" do
    it "returns a successful status for a command that succeeds" do
      expect(described_class.run("true")).to be_success
    end

    it "raises CommandFailed for a command that fails" do
      expect { described_class.run("false") }.to raise_error(Gempilot::Shell::CommandFailed)
    end

    it "names the command and exit status in the failure" do
      command = [RbConfig.ruby, "-e", "exit 3"]
      expect { described_class.run(*command) }
        .to raise_error(Gempilot::Shell::CommandFailed, "Command failed with status (3): [#{command.shelljoin}]")
    end

    it "raises CommandFailed for a command that does not exist" do
      expect { described_class.run("gempilot-no-such-command") }.to raise_error(Gempilot::Shell::CommandFailed)
    end

    it "runs in chdir" do
      mkdir("sub")
      described_class.run(RbConfig.ruby, "-e", "File.write('here', '')", chdir: "sub")
      expect(Pathname("sub/here")).to be_file
    end
  end

  describe ".capture" do
    it "returns the command's output" do
      expect(described_class.capture(*ruby_print("'hello'")).output).to eq("hello")
    end

    it "reports success" do
      expect(described_class.capture("true")).to be_success
    end

    it "reports failure without raising" do
      expect(described_class.capture("false")).not_to be_success
    end

    it "reports a missing command as a failure" do
      expect(described_class.capture("gempilot-no-such-command")).not_to be_success
    end

    it "runs in chdir" do
      mkdir("sub")
      expect(described_class.capture(*ruby_print("Dir.pwd"), chdir: "sub").output).to eq(File.realpath("sub"))
    end

    it "adds env to the command's environment" do
      expect(described_class.capture(*ruby_print("ENV['GEMPILOT_SPEC']"), env: { "GEMPILOT_SPEC" => "set" }).output)
        .to eq("set")
    end

    it "keeps the surrounding bundle by default" do
      expect(described_class.capture(*ruby_print("ENV['BUNDLE_GEMFILE'].to_s")).output).not_to be_empty
    end

    it "leaves the surrounding bundle when unbundled" do
      expect(described_class.capture(*ruby_print("ENV['BUNDLE_GEMFILE'].to_s"), unbundled: true).output).to be_empty
    end
  end

  describe ".with_gateway" do
    let(:stubs) { Gempilot::Shell::StubGateway.new }

    def run_unregistered_command
      begin
        described_class.with_gateway(stubs) { described_class.run("git", "status") }
      rescue Gempilot::Shell::UnregisteredCommand
        nil
      end
    end

    it "routes commands through the given gateway" do
      stubs.stub("gh", "release", "list").to_return(output: "v1.0.0\n")
      output = described_class.with_gateway(stubs) { described_class.capture("gh", "release", "list").output }
      expect(output).to eq("v1.0.0\n")
    end

    it "restores the previous gateway afterwards" do
      previous = described_class.gateway
      described_class.with_gateway(stubs) { nil }
      expect(described_class.gateway).to be(previous)
    end

    it "re-raises what the block raises" do
      expect { described_class.with_gateway(stubs) { described_class.run("git", "status") } }
        .to raise_error(Gempilot::Shell::UnregisteredCommand)
    end

    it "restores the previous gateway when the block raises" do
      expect { run_unregistered_command }.not_to(change { described_class.gateway })
    end
  end
end
