require "spec_helper"
require "open3"

# Integration: gempilot's own bin/setup, run against a copy of this checkout,
# installs the rbs collection through rake setup. Needs network access.
RSpec.describe "bin/setup", :integration do
  include FileUtils

  let(:gempilot_root) { Pathname(__dir__).parent.parent }
  let(:setup_run) { Bundler.with_unbundled_env { Open3.capture2e("bin/setup") } }

  around do |example|
    Dir.mktmpdir("bin_setup_spec") { |dir| Dir.chdir(dir) { example.run } }
  end

  def copy_checkout
    files = IO.popen(%w[git ls-files --cached --others --exclude-standard], chdir: gempilot_root, &:readlines)
    [*files.map(&:chomp), "Gemfile.lock"].each do |file|
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
    output, status = setup_run
    expect(status).to be_success, output
  end

  it "installs the rbs collection" do
    expect(Pathname(".gem_rbs_collection")).to be_directory
  end

  it "pins the rbs collection" do
    expect(Pathname("rbs_collection.lock.yaml")).to be_file
  end
end
