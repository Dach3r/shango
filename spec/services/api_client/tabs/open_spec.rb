require "rails_helper"

RSpec.describe ApiClient::Tabs::Open do
  let(:user) { create(:user) }
  let(:api_request) { create(:api_request) }

  it "opens a single tab however many times it is called (the unique index absorbs races)", :aggregate_failures do
    first = described_class.call(api_request:, user:).record
    second = described_class.call(api_request:, user:).record

    expect(second).to eq(first)
    expect(RequestTab.where(user:, api_request:).count).to eq(1)
  end

  it "keeps tabs of different users apart" do
    described_class.call(api_request:, user:)
    described_class.call(api_request:, user: create(:user))

    expect(RequestTab.where(api_request:).count).to eq(2)
  end
end
