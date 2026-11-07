require "spec_helper"

# Runs gempilot's own bin/setup in a copy of this repository and checks it
# installs the rbs collection. Needs network access.
RSpec.describe "bin/setup", :integration do
  include FileUtils

  let(:gempilot_root) { Pathname(__dir__).parent.parent }
  let(:setup_run) { Gempilot::Shell.capture("bin/setup", unbundled: true) }

  around do |example|
    Dir.mktmpdir("bin_setup_spec") { |dir| Dir.chdir(dir) { example.run } }
  end

  def copy_checkout
    files = Gempilot::Shell.capture("git", "ls-files", "--cached", "--others", "--exclude-standard",
                                    chdir: gempilot_root)
    [*files.output.lines(chomp: true), "Gemfile.lock"].each do |file|
      source = gempilot_root / file
      next unless source.file?

      mkdir_p(File.dirname(file))
      cp(source, file, preserve: true)
    end
  end

  before do
    copy_checkout
    rm_f("rbs_collection.lock.yaml")
    setup_run
  end

  it "succeeds" do
    expect(setup_run).to be_success
  end

  it "installs the rbs collection" do
    expect(Pathname(".gem_rbs_collection")).to be_directory
  end

  it "pins the rbs collection" do
    expect(Pathname("rbs_collection.lock.yaml")).to be_file
  end
end
