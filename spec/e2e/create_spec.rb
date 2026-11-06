require "spec_helper"
require "open3"

# End to end: runs exe/gempilot create in a child process, with no mocks or
# stubs, and inspects the gem it leaves on disk. Needs network access.
RSpec.describe "gempilot create", :integration do
  let(:gempilot_root) { Pathname(__dir__).parent.parent }
  let(:git_identity) do
    {
      "GIT_AUTHOR_NAME" => "Test Author", "GIT_AUTHOR_EMAIL" => "test@example.com",
      "GIT_COMMITTER_NAME" => "Test Author", "GIT_COMMITTER_EMAIL" => "test@example.com"
    }
  end
  let(:create_run) do
    run(
      RbConfig.ruby, (gempilot_root / "exe/gempilot").to_s, "create",
      "--author", "Test Author", "--email", "test@example.com",
      "--summary", "A test gem", "--ruby-version", RUBY_VERSION,
      "--test", "minitest", "--no-exe", "--git", "--branch", "master",
      "--gempilot-path", gempilot_root.to_s, "test_gem"
    )
  end

  around do |example|
    Dir.mktmpdir("create_e2e") { |dir| Dir.chdir(dir) { example.run } }
  end

  def run(*command, chdir: Dir.pwd)
    Bundler.with_unbundled_env { Open3.capture2e(git_identity, *command, chdir:) }
  end

  before { create_run }

  it "succeeds" do
    output, status = create_run
    expect(status).to be_success, output
  end

  it "installs the rbs collection" do
    expect(Pathname("test_gem/.gem_rbs_collection")).to be_directory
  end

  it "commits the rbs collection config and lockfile" do
    tracked, = run("git", "ls-files", "rbs_collection.yaml", "rbs_collection.lock.yaml", chdir: "test_gem")
    expect(tracked.split).to contain_exactly("rbs_collection.yaml", "rbs_collection.lock.yaml")
  end

  it "keeps the installed collection out of git" do
    _, status = run("git", "check-ignore", "-q", ".gem_rbs_collection", chdir: "test_gem")
    expect(status).to be_success
  end

  it "leaves a clean working tree" do
    porcelain, = run("git", "status", "--porcelain", chdir: "test_gem")
    expect(porcelain).to be_empty
  end

  it "passes its own default rake task" do
    output, status = run("bundle", "exec", "rake", chdir: "test_gem")
    expect(status).to be_success, output
  end
end
