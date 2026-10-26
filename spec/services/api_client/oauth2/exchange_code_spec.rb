require "rails_helper"

RSpec.describe ApiClient::Oauth2::ExchangeCode do
  let(:config) { { "grant_type" => "authorization_code", "token_url" => "https://auth.example.com/token", "client_id" => "{{client}}" } }
  let(:owner) { create(:collection, auth_type: "oauth2", auth_config: config) }
  let(:environment) { create(:environment, project: owner.project) }

  it "stores the tokens", :aggregate_failures do
    create(:variable, environment:, key: "client", value: "abc")
    stub_request(:post, config["token_url"]).to_return(status: 200, body: { access_token: "tok" }.to_json)

    result = described_class.call(owner:, code: "c", verifier: "v", redirect_uri: "https://app.test/cb", environment:)

    expect(result).to be_success
    expect(owner.reload.auth_config).to include("access_token" => "tok")
  end

  it "returns the failure message" do
    stub_request(:post, config["token_url"]).to_return(status: 400, body: { error: "invalid_grant" }.to_json)

    result = described_class.call(owner:, code: "c", verifier: "v", redirect_uri: "https://app.test/cb")

    expect(result).to be_failure
    expect(result.error).to eq("invalid_grant")
  end
end
