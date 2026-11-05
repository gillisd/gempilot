require "spec_helper"

RSpec.describe Gempilot::CLI::Commands::New do
  include FileUtils

  subject(:command) { described_class.new }

  before do
    mkdir_p("lib/my_gem")
    mkdir_p("test")
    File.write("my_gem.gemspec", 'Gem::Specification.new { |s| s.name = "my_gem" }')
  end

  def source = File.read(path)

  def adopt_rspec
    rm_rf("test")
    mkdir_p("spec")
    File.write("spec/spec_helper.rb", "")
  end

  describe "class generation" do
    context "with a top-level constant" do
      let(:path) { "lib/my_gem/authentication.rb" }

      before { command.main(["class", "MyGem::Authentication"]) }

      it "creates the class file" do
        expect(File).to exist(path)
      end

      it "nests the class inside the gem module" do
        expect(source).to include("module MyGem", "class Authentication")
      end

      it "omits the frozen string literal comment" do
        expect(source).not_to include("frozen_string_literal")
      end
    end

    context "with a nested constant" do
      let(:path) { "lib/my_gem/services/authentication.rb" }

      before { command.main(["class", "MyGem::Services::Authentication"]) }

      it "creates the namespace directory" do
        expect(File).to be_directory("lib/my_gem/services")
      end

      it "creates the class file" do
        expect(File).to exist(path)
      end

      it "nests the class inside every namespace module" do
        expect(source).to include("module MyGem", "module Services", "class Authentication")
      end
    end

    context "with a deeply nested constant" do
      let(:path) { "lib/my_gem/services/auth/token_validator.rb" }

      before { command.main(["class", "MyGem::Services::Auth::TokenValidator"]) }

      it "nests the class inside every namespace module" do
        expect(source).to include("module MyGem", "module Services", "module Auth", "class TokenValidator")
      end
    end

    context "with a multi-word namespace" do
      let(:path) { "lib/my_gem/some_name_space/new_class.rb" }

      before { command.main(["class", "MyGem::SomeNameSpace::NewClass"]) }

      it "creates the class file at the underscored path" do
        expect(File).to exist(path)
      end

      it "nests the class inside every namespace module" do
        expect(source).to include("module MyGem", "module SomeNameSpace", "class NewClass")
      end
    end
  end

  describe "class test generation" do
    context "with a minitest suite" do
      let(:path) { "test/my_gem/authentication_test.rb" }

      before { command.main(["class", "MyGem::Authentication"]) }

      it "creates the test file" do
        expect(File).to exist(path)
      end

      it "requires the test helper" do
        expect(source).to include('require "test_helper"')
      end

      it "opens the gem module" do
        expect(source).to include("module MyGem")
      end

      it "subclasses the minitest base class" do
        expect(source).to include("Minitest::Test")
      end
    end

    context "with a nested constant" do
      before { command.main(["class", "MyGem::Services::Authentication"]) }

      it "creates the test file inside the namespace directory" do
        expect(File).to exist("test/my_gem/services/authentication_test.rb")
      end
    end

    context "with an rspec suite" do
      let(:path) { "spec/my_gem/authentication_spec.rb" }

      before do
        adopt_rspec
        command.main(["class", "MyGem::Authentication"])
      end

      it "creates the spec file" do
        expect(File).to exist(path)
      end

      it "requires the spec helper" do
        expect(source).to include('require "spec_helper"')
      end

      it "describes the generated class" do
        expect(source).to include("RSpec.describe MyGem::Authentication")
      end
    end
  end

  describe "module generation" do
    context "with a top-level constant" do
      let(:path) { "lib/my_gem/middleware.rb" }

      before { command.main(["module", "MyGem::Middleware"]) }

      it "creates the module file" do
        expect(File).to exist(path)
      end

      it "nests the module inside the gem module" do
        expect(source).to include("module MyGem", "module Middleware")
      end

      it "declares no class" do
        expect(source).not_to include("class")
      end

      it "creates no test file" do
        expect(File).not_to exist("test/my_gem/middleware_test.rb")
      end
    end

    context "with a nested constant" do
      let(:path) { "lib/my_gem/services/concerns.rb" }

      before { command.main(["module", "MyGem::Services::Concerns"]) }

      it "nests the module inside every namespace module" do
        expect(source).to include("module MyGem", "module Services", "module Concerns")
      end
    end
  end

  describe "command generation" do
    let(:path) { "lib/my_gem/cli/commands/deploy.rb" }

    before do
      mkdir_p("lib/my_gem/cli/commands")
      command.main(["command", "deploy"])
    end

    it "creates the command file" do
      expect(File).to exist(path)
    end

    it "subclasses the command base class" do
      expect(source).to include("class Deploy < Command")
    end

    it "nests the command inside the commands module" do
      expect(source).to include("module MyGem", "module Commands")
    end

    it "declares a description" do
      expect(source).to include("description")
    end
  end

  describe "command test generation" do
    before { mkdir_p("lib/my_gem/cli/commands") }

    context "with a minitest suite" do
      let(:path) { "test/my_gem/cli/commands/deploy_test.rb" }

      before { command.main(["command", "deploy"]) }

      it "creates the test file" do
        expect(File).to exist(path)
      end

      it "requires the test helper" do
        expect(source).to include('require "test_helper"')
      end

      it "subclasses the minitest base class" do
        expect(source).to include("Minitest::Test")
      end

      it "references the command constant" do
        expect(source).to include("Commands::Deploy")
      end
    end

    context "with an rspec suite" do
      let(:path) { "spec/my_gem/cli/commands/deploy_spec.rb" }

      before do
        adopt_rspec
        command.main(["command", "deploy"])
      end

      it "creates the spec file" do
        expect(File).to exist(path)
      end

      it "requires the spec helper" do
        expect(source).to include('require "spec_helper"')
      end

      it "describes the generated command" do
        expect(source).to include("RSpec.describe MyGem::CLI::Commands::Deploy")
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
  end
end
