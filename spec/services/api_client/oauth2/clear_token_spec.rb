require "rails_helper"

RSpec.describe ApiClient::Oauth2::ClearToken do
  let(:owner) do
    create(:collection, auth_type: "oauth2", auth_config: { "token_url" => "https://auth.test/token", "access_token" => "a", "refresh_token" => "r", "expires_at" => "x" })
  end

  it "removes stored tokens and keeps the settings" do
    result = described_class.call(owner:)

    expect(result).to be_success
    expect(owner.reload.auth_config).to eq("token_url" => "https://auth.test/token")
  end
end
