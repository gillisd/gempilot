require "spec_helper"
require "stringio"

RSpec.describe Gempilot::CLI::Commands::Create do
  let(:command) { described_class.new(stdout: StringIO.new) }

  let(:create_args) do
    ["--author", "Test Author", "--email", "test@example.com",
     "--summary", "A test gem", "--ruby-version", "3.4.8",
     "--test", "minitest", "--no-exe", "--no-git", "test_gem"]
  end

  before { allow(command).to receive(:sh) }

  describe "generated minitest test_helper" do
    let(:test_helper) { File.read("test_gem/test/test_helper.rb") }
    let(:guarded_reporters) do
      <<~RUBY.chomp
        unless ENV["RM_INFO"]
          require "minitest/reporters"
          Minitest::Reporters.use! [Minitest::Reporters::DefaultReporter.new(color: true)]
        end
      RUBY
    end

    context "with a flat gem name" do
      before { command.main(create_args) }

      it "guards the reporters behind the RubyMine environment check" do
        expect(test_helper).to include(guarded_reporters)
      end

      it "disables plugin autoloading" do
        expect(test_helper).to include('ENV["MT_NO_PLUGINS"] = "1" unless ENV["RM_INFO"]')
      end

      it "loads the minitest autorunner" do
        expect(test_helper).to include("minitest/autorun")
      end

      it "loads the minitest reporters" do
        expect(test_helper).to include("minitest/reporters")
      end

      it "requires the gem" do
        expect(test_helper).to include('require "test_gem"')
      end

      it "has no leading blank line" do
        expect(test_helper).not_to start_with("\n")
      end
    end

    context "with a hyphenated gem name" do
      before { command.main([*create_args[...-1], "gempilot-encryption"]) }

      it "requires the nested path" do
        helper = File.read("gempilot-encryption/test/test_helper.rb")
        expect(helper).to include('require "gempilot/encryption"')
      end
    end
  end

  describe "generated rspec spec_helper" do
    context "with the rspec framework" do
      let(:spec_helper) { File.read("test_gem/spec/spec_helper.rb") }

      before { command.main([*create_args[...-1], "--test", "rspec", "test_gem"]) }

      it "requires the gem" do
        expect(spec_helper).to include('require "test_gem"')
      end

      it "configures rspec" do
        expect(spec_helper).to include("RSpec.configure")
      end

      it "disables monkey patching" do
        expect(spec_helper).to include("disable_monkey_patching!")
      end
    end
  end
end
