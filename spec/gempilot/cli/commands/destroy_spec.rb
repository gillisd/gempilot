require "spec_helper"
require "stringio"

RSpec.describe Gempilot::CLI::Commands::Destroy do
  include FileUtils

  subject(:command) { described_class.new(stdout: StringIO.new) }

  before do
    mkdir_p("lib/my_gem")
    mkdir_p("test")
    File.write("my_gem.gemspec", 'Gem::Specification.new { |s| s.name = "my_gem" }')
  end

  def seed(path)
    mkdir_p(File.dirname(path))
    File.write(path, "# placeholder\n")
  end

  def adopt_rspec
    rm_rf("test")
    mkdir_p("spec")
    File.write("spec/spec_helper.rb", "")
  end

  describe "class destruction" do
    context "with a class file" do
      before do
        seed("lib/my_gem/authentication.rb")
        command.main(["class", "MyGem::Authentication"])
      end

      it "removes the class file" do
        expect(File).not_to exist("lib/my_gem/authentication.rb")
      end
    end

    context "with a class test file" do
      before do
        seed("lib/my_gem/authentication.rb")
        seed("test/my_gem/authentication_test.rb")
        command.main(["class", "MyGem::Authentication"])
      end

      it "removes the test file" do
        expect(File).not_to exist("test/my_gem/authentication_test.rb")
      end
    end

    context "with namespace directories left empty" do
      before do
        seed("lib/my_gem/services/authentication.rb")
        seed("test/my_gem/services/authentication_test.rb")
        command.main(["class", "MyGem::Services::Authentication"])
      end

      it "removes the class file" do
        expect(File).not_to exist("lib/my_gem/services/authentication.rb")
      end

      it "removes the library namespace directory" do
        expect(File).not_to be_directory("lib/my_gem/services")
      end

      it "removes the test file" do
        expect(File).not_to exist("test/my_gem/services/authentication_test.rb")
      end

      it "removes the test namespace directory" do
        expect(File).not_to be_directory("test/my_gem/services")
      end
    end

    context "with a sibling class file" do
      before do
        seed("lib/my_gem/services/authentication.rb")
        seed("lib/my_gem/services/authorization.rb")
        command.main(["class", "MyGem::Services::Authentication"])
      end

      it "removes the class file" do
        expect(File).not_to exist("lib/my_gem/services/authentication.rb")
      end

      it "keeps the namespace directory" do
        expect(File).to be_directory("lib/my_gem/services")
      end

      it "keeps the sibling class file" do
        expect(File).to exist("lib/my_gem/services/authorization.rb")
      end
    end

    context "without a class file" do
      it "signals success" do
        expect(command.main(["class", "MyGem::NonExistent"])).to eq(0)
      end
    end

    context "with an rspec suite" do
      before do
        adopt_rspec
        seed("lib/my_gem/authentication.rb")
        seed("spec/my_gem/authentication_spec.rb")
        command.main(["class", "MyGem::Authentication"])
      end

      it "removes the class file" do
        expect(File).not_to exist("lib/my_gem/authentication.rb")
      end

      it "removes the spec file" do
        expect(File).not_to exist("spec/my_gem/authentication_spec.rb")
      end
    end
  end

  describe "module destruction" do
    before do
      seed("lib/my_gem/middleware.rb")
      seed("test/my_gem/something_test.rb")
      command.main(["module", "MyGem::Middleware"])
    end

    it "removes the module file" do
      expect(File).not_to exist("lib/my_gem/middleware.rb")
    end

    it "keeps unrelated test files" do
      expect(File).to exist("test/my_gem/something_test.rb")
    end
  end

  describe "command destruction" do
    before { seed("lib/my_gem/cli/commands/deploy.rb") }

    context "with a minitest suite" do
      before do
        seed("test/my_gem/cli/commands/deploy_test.rb")
        command.main(["command", "deploy"])
      end

      it "removes the command file" do
        expect(File).not_to exist("lib/my_gem/cli/commands/deploy.rb")
      end

      it "removes the test file" do
        expect(File).not_to exist("test/my_gem/cli/commands/deploy_test.rb")
      end
    end

    context "with an rspec suite" do
      before do
        adopt_rspec
        seed("spec/my_gem/cli/commands/deploy_spec.rb")
        command.main(["command", "deploy"])
      end

      it "removes the command file" do
        expect(File).not_to exist("lib/my_gem/cli/commands/deploy.rb")
      end

      it "removes the spec file" do
        expect(File).not_to exist("spec/my_gem/cli/commands/deploy_spec.rb")
      end
    end
  end

  describe "exit status" do
    context "without a gemspec" do
      before { rm("my_gem.gemspec") }

      it "signals failure" do
        expect(command.main(["class", "MyGem::Foo"])).to eq(1)
      end
    end

    context "with an unknown type" do
      it "signals failure" do
        expect(command.main(["widget", "MyGem::Foo"])).to eq(1)
      end
    end

    context "with a foreign root namespace" do
      it "signals success" do
        expect(command.main(["class", "WrongGem::Foo"])).to eq(0)
      end
    end
  end
end
