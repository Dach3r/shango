require "rails_helper"

RSpec.describe ApiClient::SetCookie do
  describe ".split" do
    it "separates cookies merged into one header, keeping dates intact" do
      expect(described_class.split("a=1; Expires=Wed, 21 Oct 2037 07:28:00 GMT; Path=/, b=2; Path=/")).to eq(["a=1; Expires=Wed, 21 Oct 2037 07:28:00 GMT; Path=/", "b=2; Path=/"])
    end

    it "returns nothing without a header" do
      expect(described_class.split(nil)).to eq([])
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
  end
end
