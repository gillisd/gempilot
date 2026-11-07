## Runs commands against an installed build of gempilot, outside the test's bundle.
##
##   RSpec.describe "gempilot create" do
##     include E2EHelpers
##
##     it "creates the gem" do
##       expect(create("my_gem")).to be_success
##     end
##   end
module E2EHelpers
  GIT_IDENTITY = {
    "GIT_AUTHOR_NAME" => "Test Author", "GIT_AUTHOR_EMAIL" => "test@example.com",
    "GIT_COMMITTER_NAME" => "Test Author", "GIT_COMMITTER_EMAIL" => "test@example.com"
  }.freeze

  def self.included(group)
    group.let(:gempilot) { InstalledGempilot.new(Dir.pwd).install }
    group.around do |example|
      Dir.mktmpdir("gempilot_e2e") { |dir| Dir.chdir(dir) { example.run } }
    end
  end

  def run(*command, chdir: Dir.pwd)
    Gempilot::Shell.capture(*command, chdir:, env: gempilot.env.merge(GIT_IDENTITY), unbundled: true)
  end

  def create(name, *options)
    run("gempilot", "create",
        "--author", "Test Author", "--email", "test@example.com",
        "--summary", "A test gem", "--ruby-version", RUBY_VERSION,
        "--test", "minitest", "--no-exe", "--git", "--branch", "master", *options, name)
  end
end
