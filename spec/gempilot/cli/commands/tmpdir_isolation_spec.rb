require "spec_helper"

RSpec.describe "command spec tmpdir isolation" do
  include FileUtils

  let(:repo_root) do
    Pathname(__dir__).ascend.find { |dir| dir.join("gempilot.gemspec").file? } ||
      raise("could not locate gempilot.gemspec above #{__dir__}")
  end
  let(:tmp_root) { Pathname(Dir.tmpdir).realpath }
  let(:working_dir) { Pathname(Dir.pwd).realpath }

  def nested_within?(parent, child)
    child == parent || child.to_s.start_with?("#{parent}#{File::SEPARATOR}")
  end

  it "auto-applies the :tmpdir tag to examples in this directory" do
    expect(RSpec.current_example.metadata).to include(tmpdir: true)
  end

  it "runs outside the repository working tree" do
    expect(nested_within?(repo_root, working_dir)).to be(false)
  end

  it "runs inside a system temp directory" do
    expect(nested_within?(tmp_root, working_dir)).to be(true)
  end

  it "starts each example in an empty working directory" do
    expect(working_dir.children).to be_empty
  end

  context "when a sibling example scaffolds files" do
    it "confines writes to its own working directory" do
      touch "scaffolded.txt"
      expect(working_dir.children.map { it.basename.to_s }).to contain_exactly("scaffolded.txt")
    end

    it "never observes another example's scaffolded files" do
      expect(working_dir.children).to be_empty
    end
  end
end
