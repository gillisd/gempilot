require "spec_helper"
require "stringio"

# Integration: runs the real bin/setup -> bundle install -> rake setup ->
# rbs:setup chain inside a freshly scaffolded gem. Needs network access.
RSpec.describe Gempilot::CLI::Commands::Create, :integration do
  let(:command) { described_class.new(stdout: StringIO.new) }
  let(:gempilot_root) { File.expand_path("../../../..", __dir__) }

  around do |example|
    git_identity = {
      "GIT_AUTHOR_NAME" => "Test Author", "GIT_AUTHOR_EMAIL" => "test@example.com",
      "GIT_COMMITTER_NAME" => "Test Author", "GIT_COMMITTER_EMAIL" => "test@example.com"
    }
    saved = ENV.to_h.slice(*git_identity.keys)
    ENV.update(git_identity)
    example.run
  ensure
    git_identity.each_key { ENV.delete(it) }
    ENV.update(saved)
  end

  # The scaffolded Gemfile resolves gempilot from rubygems.org; point it at
  # this checkout so the generated Rakefile loads the RBSTask under test.
  def point_gemfile_at_checkout
    gemfile = Pathname("Gemfile")
    gemfile.write(gemfile.read.sub(/^gem "gempilot".*$/,
                                   %(gem "gempilot", path: #{gempilot_root.inspect}, require: false)))
  end

  before do
    allow(command).to receive(:sh).and_wrap_original do |original, *args|
      point_gemfile_at_checkout if args == ["bin/setup"]
      original.call(*args)
    end
    command.main([
                   "--author", "Test Author", "--email", "test@example.com",
                   "--summary", "A test gem", "--ruby-version", RUBY_VERSION,
                   "--test", "minitest", "--no-exe", "--git", "--branch", "master", "test_gem"
                 ])
  end

  it "runs bin/setup in the new gem" do
    expect(command).to have_received(:sh).with("bin/setup")
  end

  it "installs the rbs collection" do
    expect(Pathname("test_gem/.gem_rbs_collection")).to be_directory
  end

  it "commits the rbs collection lockfile" do
    tracked = IO.popen(%w[git ls-files rbs_collection.yaml rbs_collection.lock.yaml], chdir: "test_gem", &:read)
    expect(tracked.split).to contain_exactly("rbs_collection.yaml", "rbs_collection.lock.yaml")
  end

  it "keeps the installed collection out of git" do
    ignored = system("git", "check-ignore", "-q", ".gem_rbs_collection", chdir: "test_gem")
    expect(ignored).to be(true)
  end
end
