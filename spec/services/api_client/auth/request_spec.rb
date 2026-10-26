require "rails_helper"

RSpec.describe ApiClient::Auth::Request do
  subject(:request) { described_class.new(http_method: "GET", url:, headers: { "X-Token" => "a" }, body: nil) }

  let(:url) { "https://api.example.com/items" }

  describe "#header?" do
    it "matches names case-insensitively", :aggregate_failures do
      expect(request.header?("x-token")).to be(true)
      expect(request.header?("Other")).to be(false)
    end
  end

  describe "#add_query" do
    it "adds the first parameter" do
      request.add_query("a b", "c&d")

      expect(request.url).to eq("https://api.example.com/items?a+b=c%26d")
    end

    context "when the url already has a query" do
      let(:url) { "https://api.example.com/items?page=1" }

      it "appends the parameter" do
        request.add_query("key", "v")

        expect(request.url).to eq("https://api.example.com/items?page=1&key=v")
      end
    end
  end
end
