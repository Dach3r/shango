require "rails_helper"

RSpec.describe ApiClient::Imports::Support do
  describe ".request" do
    it "rebuilds the URL from enabled params and normalizes the method", :aggregate_failures do
      params = [described_class.row("a", "1"), described_class.row("b", "2", enabled: false), described_class.row("c", "")]
      attrs = described_class.request(name: "  ", http_method: "trace", url: "http://x/y?old=1", query_params: params)
      expect(attrs).to include(name: "Untitled request", http_method: "GET", url: "http://x/y?a=1&c")
    end

    it "keeps the URL when no param is enabled" do
      expect(described_class.request(name: "n", url: "http://x").fetch(:url)).to eq("http://x")
    end
  end

  it "builds folders, environments and variables with defaults", :aggregate_failures do
    expect(described_class.folder(name: "").fetch(:name)).to eq("Untitled folder")
    expect(described_class.environment(name: nil).fetch(:name)).to eq("Imported environment")
    expect(described_class.variable("k", nil, secret: true, enabled: false)).to eq(key: "k", value: "", secret: true, enabled: false)
  end

  it "maps mime types to body types", :aggregate_failures do
    {
      "application/json" => "json", "text/xml" => "xml", "application/x-www-form-urlencoded" => "form_urlencoded",
      "multipart/form-data" => "multipart", "text/plain" => "text"
    }.each { |mime, type| expect(described_class.body_type_for(mime)).to eq(type) }
  end

  it "counts nodes" do
    expect(described_class.count_nodes({ "a" => [1, 2], "b" => { "c" => 3 } })).to eq(6)
  end
end
