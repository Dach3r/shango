require "rails_helper"

RSpec.describe ApiClient::Tabs::CloseMany do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:saved) { create(:api_request, project:) }

  def open_tab(api_request)
    ApiClient::Tabs::Open.call(api_request:, user:)
    api_request
  end

  it "closes saved tabs without deleting the requests", :aggregate_failures do
    open_tab(saved)

    described_class.call(api_requests: [saved], user:)

    expect(RequestTab.where(user:)).not_to exist
    expect(saved.reload).to be_persisted
  end

  it "discards untouched drafts" do
    draft = open_tab(ApiClient::Requests::CreateDraft.call(project:, user:).record)

    expect { described_class.call(api_requests: [draft], user:) }.to change(ApiRequest, :count).by(-1)
  end

  it "keeps drafts with edits open", :aggregate_failures do
    draft = open_tab(ApiClient::Requests::CreateDraft.call(project:, user:).record)
    draft.update!(name: "Edited")

    described_class.call(api_requests: [draft.reload], user:)

    expect(draft.reload).to be_persisted
    expect(RequestTab.where(user:, api_request: draft)).to exist
  end
end
