require "rails_helper"

RSpec.describe ApiClient::Auth::Basic do
  let(:request) { ApiClient::Auth::Request.new(http_method: "GET", url: "https://a.test", headers: {}, body: nil) }

  it "sets the basic authorization header" do
    described_class.new({ "username" => "ada", "password" => "pw" }).apply(request)

    expect(request.headers["Authorization"]).to eq("Basic #{Base64.strict_encode64("ada:pw")}")
  end

  it "requires a username" do
    expect { described_class.new({}).apply(request) }.to raise_error(ApiClient::Auth::ConfigurationError)
  end
end
