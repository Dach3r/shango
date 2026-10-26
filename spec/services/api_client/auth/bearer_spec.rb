require "rails_helper"

RSpec.describe ApiClient::Auth::Bearer do
  let(:request) { ApiClient::Auth::Request.new(http_method: "GET", url: "https://a.test", headers: {}, body: nil) }

  it "uses the default prefix" do
    described_class.new({ "token" => "t" }).apply(request)

    expect(request.headers["Authorization"]).to eq("Bearer t")
  end

  it "uses a custom prefix" do
    described_class.new({ "token" => "t", "prefix" => "Token" }).apply(request)

    expect(request.headers["Authorization"]).to eq("Token t")
  end

  it "requires a token" do
    expect { described_class.new({}).apply(request) }.to raise_error(ApiClient::Auth::ConfigurationError)
  end
end
