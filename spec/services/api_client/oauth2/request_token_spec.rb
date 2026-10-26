require "rails_helper"

RSpec.describe ApiClient::Oauth2::RequestToken do
  let(:config) { { "grant_type" => "client_credentials", "token_url" => "https://auth.example.com/token", "client_id" => "{{client}}" } }
  let(:owner) { create(:collection, auth_type: "oauth2", auth_config: config) }
  let(:environment) { create(:environment, project: owner.project) }

  it "fetches and stores a token", :aggregate_failures do
    create(:variable, environment:, key: "client", value: "abc")
    stub_request(:post, config["token_url"]).to_return(status: 200, body: { access_token: "tok" }.to_json)

    result = described_class.call(owner:, environment:)

    expect(result).to be_success
    expect(owner.reload.auth_config).to include("access_token" => "tok")
  end

  it "works without an environment" do
    stub_request(:post, config["token_url"]).to_return(status: 200, body: { access_token: "tok" }.to_json)

    expect(described_class.call(owner:)).to be_success
  end

  it "refuses the authorization code grant" do
    owner.update!(auth_config: config.merge("grant_type" => "authorization_code"))

    result = described_class.call(owner:)

    expect(result).to be_failure
    expect(result.error).to eq(I18n.t("workbench.oauth2.unsupported_grant"))
  end

  it "returns token endpoint errors" do
    stub_request(:post, config["token_url"]).to_return(status: 401, body: { error: "invalid_client" }.to_json)

    expect(described_class.call(owner:).error).to eq("invalid_client")
  end
end
