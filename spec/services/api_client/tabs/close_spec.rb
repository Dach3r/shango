require "rails_helper"

RSpec.describe ApiClient::Tabs::Close do
  let(:user) { create(:user) }
  let(:api_request) { create(:api_request) }

  it "closes the tab and keeps the request", :aggregate_failures do
    create(:request_tab, user:, api_request:)

    expect(described_class.call(api_request:, user:)).to be_success
    expect(RequestTab.where(user:)).not_to exist
    expect(api_request.reload).to be_persisted
  end

  it "is harmless when no tab is open" do
    expect(described_class.call(api_request:, user:)).to be_success
  end

  it "keeps tabs of other users and other requests", :aggregate_failures do
    others = [create(:request_tab, api_request:), create(:request_tab, user:)]
    described_class.call(api_request:, user:)

    expect(RequestTab.where(id: others.map(&:id)).count).to eq(2)
  end
end
