require "rails_helper"

RSpec.describe ApiClient::Exports::Credentials do
  let(:request) { build(:api_request, auth_type: "oauth2", auth_config: { "grant_type" => "client_credentials", "client_secret" => "csec", "access_token" => "at", "junk" => "x" }) }

  it "empties secret fields and leaves tokens out by default", :aggregate_failures do
    config = described_class.new(include: false).auth_config(request)

    expect(config).to eq("grant_type" => "client_credentials", "client_secret" => "")
  end

  it "keeps secrets and OAuth tokens when asked", :aggregate_failures do
    config = described_class.new(include: true).auth_config(request)

    expect(config).to eq("grant_type" => "client_credentials", "client_secret" => "csec", "access_token" => "at")
  end

  it "has no config for inherit and none" do
    expect(described_class.new(include: true).auth_config(build(:api_request, auth_type: "inherit"))).to eq({})
  end

  it "masks secret variable values only when credentials are left out", :aggregate_failures do
    secret = build(:variable, :secret, value: "s3cret")
    plain = build(:variable, value: "v")

    expect(described_class.new(include: false).variable_value(secret)).to eq("")
    expect(described_class.new(include: false).variable_value(plain)).to eq("v")
    expect(described_class.new(include: true).variable_value(secret)).to eq("s3cret")
  end
end
