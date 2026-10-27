require "rails_helper"

RSpec.describe ApiClient::SetCookie do
  describe ".split" do
    it "separates cookies merged into one header, keeping dates intact" do
      expect(described_class.split("a=1; Expires=Wed, 21 Oct 2037 07:28:00 GMT; Path=/, b=2; Path=/")).to eq(["a=1; Expires=Wed, 21 Oct 2037 07:28:00 GMT; Path=/", "b=2; Path=/"])
    end

    it "returns nothing without a header" do
      expect(described_class.split(nil)).to eq([])
    end

    it "does not split on commas inside a value", :aggregate_failures do
      expect(described_class.split("a=1,2; Path=/, b=3")).to eq(["a=1,2; Path=/", "b=3"])
      expect(described_class.split("a=x, y; Path=/")).to eq(["a=x, y; Path=/"])
    end

    it "ignores blank segments", :aggregate_failures do
      expect(described_class.split("")).to eq([])
      expect(described_class.split("  ")).to eq([])
    end

    it "keeps a single cookie with an Expires date whole" do
      expect(described_class.split("a=1; expires=Thu, 01-Jan-2037 00:00:00 GMT")).to eq(["a=1; expires=Thu, 01-Jan-2037 00:00:00 GMT"])
    end
  end

  describe ".parse" do
    it "reads the name, value and lowercased attributes", :aggregate_failures do
      cookie = described_class.parse("_session=abc; Path=/; HttpOnly; Max-Age=60")

      expect(cookie).to have_attributes(name: "_session", value: "abc", attributes: { "path" => "/", "httponly" => "", "max-age" => "60" })
    end

    it "ignores lines without a name or a value", :aggregate_failures do
      expect(described_class.parse("=abc")).to be_nil
      expect(described_class.parse("novalue")).to be_nil
    end

    it "ignores values over the given length" do
      expect(described_class.parse("a=#{"x" * 11}", max_value_length: 10)).to be_nil
    end

    it "accepts an empty value", :aggregate_failures do
      expect(described_class.parse("a=")).to have_attributes(name: "a", value: "", attributes: {})
      expect(described_class.parse("a=; Max-Age=0").attributes).to eq({ "max-age" => "0" })
    end

    it "accepts a value of exactly the given length" do
      expect(described_class.parse("a=#{"x" * 10}", max_value_length: 10)).to have_attributes(value: "x" * 10)
    end

    it "keeps equals signs inside the value and quotes as they come", :aggregate_failures do
      expect(described_class.parse("t=YWJj==; Path=/").value).to eq("YWJj==")
      expect(described_class.parse(%(q="a b"; Path=/)).value).to eq(%("a b"))
    end

    it "trims spaces around names, values and attributes", :aggregate_failures do
      cookie = described_class.parse("  a  =  1  ;  PATH = /x  ;   Secure  ")

      expect(cookie).to have_attributes(name: "a", value: "1", attributes: { "path" => "/x", "secure" => "" })
    end

    it "lets the last repeated attribute win" do
      expect(described_class.parse("a=1; Path=/a; Path=/b").attributes["path"]).to eq("/b")
    end

    it "reads unicode values" do
      expect(described_class.parse("name=café").value).to eq("café")
    end
  end
end
