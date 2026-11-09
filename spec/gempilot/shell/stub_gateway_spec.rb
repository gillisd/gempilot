require "spec_helper"

RSpec.describe Gempilot::Shell::StubGateway do
  let(:stubs) { described_class.new }

  def with_stubs(&)
    Gempilot::Shell.with_gateway(stubs, &)
  end

  describe "an unregistered command" do
    it "is refused" do
      expect { with_stubs { Gempilot::Shell.run("git", "push") } }
        .to raise_error(Gempilot::Shell::UnregisteredCommand, /git push/)
    end

    it "is refused when captured" do
      expect { with_stubs { Gempilot::Shell.capture("git", "status") } }
        .to raise_error(Gempilot::Shell::UnregisteredCommand)
    end

    it "is refused when exec'd" do
      expect { with_stubs { Gempilot::Shell.exec("bin/console") } }
        .to raise_error(Gempilot::Shell::UnregisteredCommand)
    end

    it "shows how to stub it" do
      expect { with_stubs { Gempilot::Shell.run("gh", "release", "list") } }
        .to raise_error(Gempilot::Shell::UnregisteredCommand, a_string_including('stub("gh", "release", "list")'))
    end
  end

  describe "a stubbed command" do
    it "succeeds with no output by default" do
      stubs.stub("gh", "release", "list")
      expect(with_stubs { Gempilot::Shell.capture("gh", "release", "list") }).to have_attributes(output: "")
    end

    it "returns the stubbed output" do
      stubs.stub("git", "config", "user.name").to_return(output: "Ada\n")
      expect(with_stubs { Gempilot::Shell.capture("git", "config", "user.name").output }).to eq("Ada\n")
    end

    it "makes run raise CommandFailed when stubbed to fail" do
      stubs.stub("bundle", "exec", "rake", "release").to_return(exitstatus: 1)
      expect { with_stubs { Gempilot::Shell.run("bundle", "exec", "rake", "release") } }
        .to raise_error(Gempilot::Shell::CommandFailed, /status \(1\)/)
    end

    it "does not match a command with different arguments" do
      stubs.stub("gh", "release", "list")
      expect { with_stubs { Gempilot::Shell.run("gh", "release", "view") } }
        .to raise_error(Gempilot::Shell::UnregisteredCommand)
    end
  end

  describe "#invocations" do
    it "records each command with how it was run" do
      stubs.stub("bin/setup")
      with_stubs { Gempilot::Shell.run("bin/setup", chdir: "my_gem", env: { "CI" => "1" }, unbundled: true) }
      expect(stubs.invocations).to contain_exactly(
        Gempilot::Shell::Invocation.new(command: ["bin/setup"], chdir: "my_gem", env: { "CI" => "1" }, unbundled: true),
      )
    end
  end

  describe "#ran?" do
    before { stubs.stub("gh", "release", "list") }

    it "is true for a command that ran" do
      with_stubs { Gempilot::Shell.run("gh", "release", "list") }
      expect(stubs).to be_ran("gh", "release", "list")
    end

    it "is false for a command that did not run" do
      expect(stubs).not_to be_ran("gh", "release", "list")
    end
  end
end
