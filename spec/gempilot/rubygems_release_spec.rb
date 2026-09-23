require "spec_helper"

RSpec.describe Gempilot::RubygemsRelease do
  let(:project) { Gempilot::Project.new(Dir.pwd) }
  let(:release) { described_class.new(project) }
  let(:no_packages_error) { %r{No packages for my_gem 1\.2\.3 found in pkg/; run rake build first} }

  around do |example|
    Dir.mktmpdir("rubygems_release_spec") { |dir| Dir.chdir(dir) { example.run } }
  end

  before do
    Pathname("lib/my_gem").mkpath
    File.write "lib/my_gem.rb", "module MyGem; end\n"
    File.write "lib/my_gem/version.rb", <<~RUBY
      module MyGem
        VERSION = "1.2.3".freeze
      end
    RUBY
    allow(release).to receive(:sh)
  end

  def package(*names)
    Pathname("pkg").mkpath
    names.each { FileUtils.touch("pkg/#{it}") }
  end

  def pkg(name)
    project.root.join("pkg", name).to_s
  end

  describe "#push" do
    it "pushes the plain gem of the current version" do
      package "my_gem-1.2.3.gem"
      release.push
      expect(release).to have_received(:sh).with("gem", "push", pkg("my_gem-1.2.3.gem"))
    end

    it "pushes every gem of the current version in sorted order", :aggregate_failures do
      package "my_gem-1.2.3.gem", "my_gem-1.2.3-x86_64-linux.gem", "my_gem-1.2.3-arm64-darwin.gem"
      release.push
      expect(release).to have_received(:sh).with("gem", "push", pkg("my_gem-1.2.3-arm64-darwin.gem")).ordered
      expect(release).to have_received(:sh).with("gem", "push", pkg("my_gem-1.2.3-x86_64-linux.gem")).ordered
      expect(release).to have_received(:sh).with("gem", "push", pkg("my_gem-1.2.3.gem")).ordered
    end

    context "when pkg also holds other versions and other gems" do
      before { package "my_gem-1.2.3.gem", "my_gem-1.2.30.gem", "my_gem-1.2.3.1.gem", "other-1.2.3.gem" }

      it "pushes only the gems of the current version", :aggregate_failures do
        release.push
        expect(release).to have_received(:sh).with("gem", "push", pkg("my_gem-1.2.3.gem"))
        expect(release).to have_received(:sh).once
      end
    end

    it "raises without pushing when pkg holds no gem of the current version", :aggregate_failures do
      package "my_gem-1.2.30.gem"
      expect { release.push }.to raise_error(RuntimeError, no_packages_error)
      expect(release).not_to have_received(:sh)
    end

    it "raises when pkg does not exist" do
      expect { release.push }.to raise_error(RuntimeError, no_packages_error)
    end
  end
end
