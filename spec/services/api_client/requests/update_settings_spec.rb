require "rails_helper"

RSpec.describe ApiClient::Requests::UpdateSettings do
  let(:api_request) { create(:api_request, name: "Kept", settings: { "timeout" => 10 }) }

  it "saves the given settings and keeps the rest", :aggregate_failures do
    result = described_class.call(api_request:, settings: { "follow_redirects" => "0", "max_redirects" => "3" })

    expect(result).to be_success
    expect(api_request.reload.setting(:follow_redirects)).to be(false)
    expect(api_request.setting(:max_redirects)).to eq(3)
    expect(api_request.setting(:timeout)).to eq(10)
    expect(api_request.name).to eq("Kept")
  end

  it "fails when the request is invalid" do
    api_request.name = ""

    expect(described_class.call(api_request:, settings: { "timeout" => "5" })).not_to be_success
  end
end
