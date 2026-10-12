require "spec_helper"

RSpec.describe Gempilot::CLI::Commands::Bump do
  include FileUtils

  subject(:command) { described_class.new }

  let(:system_calls) { [] }

  before do
    allow(command).to receive(:system) { |*args| system_calls << args }
    File.write("my_gem.gemspec", 'Gem::Specification.new { |s| s.name = "my_gem" }')
    mkdir_p("lib/my_gem")
    File.write("lib/my_gem/version.rb", <<~RUBY)
      module MyGem
        VERSION = "1.2.3".freeze
      end
    RUBY
  end

  describe "rake delegation" do
    context "without a segment" do
      it "bumps the patch segment" do
        command.main([])
        expect(system_calls).to include(["bundle", "exec", "rake", "version:bump[patch]"])
      end
    end

    %w[patch minor major dev tiny].each do |segment|
      context "with the #{segment} segment" do
        it "bumps the #{segment} segment" do
          command.main([segment])
          expect(system_calls).to include(["bundle", "exec", "rake", "version:bump[#{segment}]"])
        end
      end
    end
  end

  describe "error handling" do
    context "without a gemspec" do
      before { rm("my_gem.gemspec") }

      it "exits with status 1" do
        expect(command.main([])).to eq(1)
      end
    end

    context "with an unknown segment" do
      it "exits with status 1" do
        expect(command.main(["hotfix"])).to eq(1)
      end

      it "skips rake" do
        command.main(["hotfix"])
        expect(system_calls).to be_empty
      end
    end
  end
end
