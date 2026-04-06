require_relative "../../../lib/core_ext/string/refinements/inflectable"

using String::Inflectable

RSpec.describe String::Inflectable do
  describe "#camelize" do
    it "camelizes a snake_case string" do
      expect("my_gem".camelize).to eq("MyGem")
    end

    it "converts slashes to namespaces" do
      expect("my/gem".camelize).to eq("My::Gem")
    end

    it "capitalizes a single word" do
      expect("gem".camelize).to eq("Gem")
    end

    it "strips hyphens and camelizes" do
      expect("my-gem".camelize).to eq("MyGem")
    end

    it "preserves numeric segments with underscore prefix" do
      expect("v_2".camelize).to eq("V_2")
    end
  end

  describe "#underscore" do
    it "underscores CamelCase" do
      expect("MyGem".underscore).to eq("my_gem")
    end

    it "underscores consecutive capitals" do
      expect("CLI".underscore).to eq("cli")
    end

    it "underscores acronyms followed by lowercase" do
      expect("HTTPClient".underscore).to eq("http_client")
    end

    it "preserves existing underscores" do
      expect("my_gem".underscore).to eq("my_gem")
    end

    it "converts hyphens to underscores" do
      expect("my-gem".underscore).to eq("my_gem")
    end
  end

  describe "#dasherize" do
    it "converts underscores to hyphens" do
      expect("my_gem".dasherize).to eq("my-gem")
    end

    it "leaves non-underscored strings unchanged" do
      expect("mygem".dasherize).to eq("mygem")
    end
  end

  describe "class method form" do
    it "camelizes via String.camelize" do
      expect(String.camelize("my_gem")).to eq("MyGem")
    end

    it "underscores via String.underscore" do
      expect(String.underscore("MyGem")).to eq("my_gem")
    end

    it "dasherizes via String.dasherize" do
      expect(String.dasherize("my_gem")).to eq("my-gem")
    end
  end
end
