require "spec_helper"

RSpec.describe Gempilot::GemConstant do
  def constant(input, gem_module: "MyGem", require_path: "my_gem")
    described_class.new(input: input, gem_module: gem_module, require_path: require_path)
  end

  describe "#qualified" do
    it "prepends the gem module to a bare suffix" do
      expect(constant("Services::Auth").qualified).to eq("MyGem::Services::Auth")
    end

    it "leaves an already-rooted constant unchanged" do
      expect(constant("MyGem::Services::Auth").qualified).to eq("MyGem::Services::Auth")
    end

    it "matches on the root segment for multi-segment modules" do
      c = constant("My::Widget", gem_module: "My::Gem", require_path: "my/gem")
      expect(c.qualified).to eq("My::Widget")
    end

    it "prepends the full module to a bare suffix under a multi-segment module" do
      c = constant("Widget", gem_module: "My::Gem", require_path: "my/gem")
      expect(c.qualified).to eq("My::Gem::Widget")
    end
  end

  describe "#namespaces / #name" do
    it "splits the qualified constant", :aggregate_failures do
      c = constant("Services::Auth")
      expect(c.namespaces).to eq(%w[MyGem Services])
      expect(c.name).to eq("Auth")
    end
  end

  describe "#lib_path" do
    it "builds the underscored source path" do
      expect(constant("Services::Auth").lib_path).to eq("lib/my_gem/services/auth.rb")
    end
  end

  describe "#test_path" do
    it "builds the rspec path" do
      expect(constant("Services::Auth").test_path(:rspec)).to eq("spec/my_gem/services/auth_spec.rb")
    end

    it "builds the minitest path" do
      expect(constant("Services::Auth").test_path(:minitest)).to eq("test/my_gem/services/auth_test.rb")
    end

    it "does not duplicate segments for multi-segment (hyphenated) modules" do
      c = constant("Widget", gem_module: "My::Gem", require_path: "my/gem")
      expect(c.test_path(:minitest)).to eq("test/my/gem/widget_test.rb")
    end
  end
end
