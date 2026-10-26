require "rails_helper"

RSpec.describe ApiClient::Oauth2::Authorize do
  let(:config) do
    { "grant_type" => "authorization_code", "authorization_url" => "https://auth.example.com/authorize", "client_id" => "{{client}}", "scope" => "read" }
  end
  let(:owner) { create(:collection, auth_type: "oauth2", auth_config: config) }
  let(:environment) { create(:environment, project: owner.project) }

  it "builds a PKCE authorization url resolving variables", :aggregate_failures do
    create(:variable, environment:, key: "client", value: "abc")

    result = described_class.call(owner:, redirect_uri: "https://app.test/cb", environment:)
    query = Rack::Utils.parse_query(URI.parse(result.data[:url]).query)

    expect(result).to be_success
    expect(result.data[:url]).to start_with("https://auth.example.com/authorize?")
    expect(query).to include("client_id" => "abc", "scope" => "read", "state" => result.data[:state], "code_challenge_method" => "S256", "redirect_uri" => "https://app.test/cb")
    expect(query).not_to include("audience")
    expect(query["code_challenge"]).to eq(Base64.urlsafe_encode64(Digest::SHA256.digest(result.data[:verifier]), padding: false))
  end

  it "appends to an existing query string" do
    owner.update!(auth_config: config.merge("authorization_url" => "https://auth.example.com/authorize?tenant=1"))

    result = described_class.call(owner:, redirect_uri: "https://app.test/cb")

    expect(result.data[:url]).to start_with("https://auth.example.com/authorize?tenant=1&")
  end

  it "fails without an authorization url" do
    owner.update!(auth_config: config.except("authorization_url"))

    result = described_class.call(owner:, redirect_uri: "https://app.test/cb")

    expect(result).to be_failure
    expect(result.error).to eq(I18n.t("workbench.oauth2.missing_authorization_url"))
  end
end
