RSpec.describe Gempilot do
  it "has a version number" do
    expect(Gempilot::VERSION).not_to be_nil
  end

  it "roots the gem at a pathname" do
    expect(Gempilot::ROOT).to be_a(Pathname)
  end
end
