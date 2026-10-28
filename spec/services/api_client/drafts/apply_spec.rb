require "rails_helper"

RSpec.describe ApiClient::Drafts::Apply do
  let(:user) { create(:user) }
  let(:api_request) { create(:api_request) }

  it "puts the pending edits back on the request in memory", :aggregate_failures do
    create(:request_draft, :for_request, user:, api_request:, project: api_request.project, payload: { url: "https://edited.test", http_method: "PUT" }.to_json)

    expect(described_class.call(api_request:, user:)).to be(true)
    expect(api_request).to have_attributes(url: "https://edited.test", http_method: "PUT")
    expect(api_request.reload.url).not_to eq("https://edited.test")
  end

  it "leaves the settings alone, which are saved as they change", :aggregate_failures do
    create(:request_draft, :for_request, user:, api_request:, project: api_request.project, payload: { settings: { timeout: 5 } }.to_json)

    described_class.call(api_request:, user:)

    expect(api_request.setting(:timeout)).to eq(ApiRequest::DEFAULT_SETTINGS["timeout"])
  end

  it "does nothing without pending edits", :aggregate_failures do
    expect(described_class.call(api_request:, user:)).to be(false)
    expect(api_request).not_to be_changed
  end

  it "ignores the pending edits of other users" do
    create(:request_draft, :for_request, api_request:, project: api_request.project, payload: { url: "https://other.test" }.to_json)

    expect(described_class.call(api_request:, user:)).to be(false)
  end
end
