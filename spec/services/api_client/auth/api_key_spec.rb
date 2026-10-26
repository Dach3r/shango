require "rails_helper"

RSpec.describe ApiClient::Auth::ApiKey do
  let(:request) { ApiClient::Auth::Request.new(http_method: "GET", url: "https://a.test/x", headers: {}, body: nil) }

  it "adds a header by default" do
    described_class.new({ "key" => "X-Key", "value" => "v" }).apply(request)

    expect(request.headers).to eq("X-Key" => "v")
  end

  it "adds a query parameter" do
    described_class.new({ "key" => "k", "value" => "v", "add_to" => "query" }).apply(request)

    expect(request.url).to eq("https://a.test/x?k=v")
  end

  it "requires key and value" do
    expect { described_class.new({}).apply(request) }.to raise_error(ApiClient::Auth::ConfigurationError, "Missing key, value")
  end
end
