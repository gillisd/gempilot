require "spec_helper"

WIRING_ABOVE_DEFAULT = /BetterleaksTask\.new\n\ntask default/

RSpec.describe Gempilot::Betterleaks do
  let(:generator) { instance_spy(Gempilot::CLI::Generator) }

  around { |example| Dir.mktmpdir("betterleaks_spec") { |dir| Dir.chdir(dir) { example.run } } }

  describe "#install" do
    before do
      FileUtils.mkdir_p("bin")
      File.write("Rakefile", "require \"rake\"\n\ntask default: :test\n")
      File.write("bin/setup", "bundle install\n")
      described_class.new(generator, root: ".").install
    end

    it "copies the pre-commit hook from the template" do
      expect(generator).to have_received(:cp).with("githooks/pre-commit", "./.githooks/pre-commit")
    end

    it "marks the hook executable" do
      expect(generator).to have_received(:chmod).with("+x", "./.githooks/pre-commit")
    end

    it "copies the CI workflow from the template" do
      expect(generator).to have_received(:cp)
        .with("dotfiles/github/workflows/secrets.yml", "./.github/workflows/secrets.yml")
    end

    it "weaves the rake wiring above the default task" do
      expect(generator).to have_received(:update)
        .with("./Rakefile", a_string_matching(WIRING_ABOVE_DEFAULT))
    end

    it "appends the hooks-path line to bin/setup" do
      expect(generator).to have_received(:update)
        .with("./bin/setup", a_string_including("git config core.hooksPath .githooks"))
    end
  end

  describe Gempilot::Betterleaks::Insertion do
    it "skips a file that already contains the snippet" do
      File.write("Rakefile", "Gempilot::BetterleaksTask.new\n")
      described_class.new(path: "Rakefile", snippet: "Gempilot::BetterleaksTask.new").install(generator)

      expect(generator).to have_received(:skip).with("Rakefile")
    end

    it "appends the snippet when no anchor is given" do
      File.write("script", "bundle install\n")
      described_class.new(path: "script", snippet: "extra").install(generator)

      expect(generator).to have_received(:update).with("script", "bundle install\n\nextra\n")
    end
  end

  describe Gempilot::Betterleaks::Template do
    it "skips an existing destination without copying" do
      File.write("hook", "present\n")
      described_class.new(source: "src", dest: "hook").install(generator)

      expect(generator).to have_received(:skip).with("hook")
    end
  end
end
