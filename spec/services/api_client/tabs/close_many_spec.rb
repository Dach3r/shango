require "rails_helper"

RSpec.describe ApiClient::Tabs::CloseMany do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:saved) { create(:api_request, project:) }

  def open_tab(api_request)
    ApiClient::Tabs::Open.call(api_request:, user:)
    api_request
  end

  it "forgets the unsaved edits of the closed tabs" do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    open_tab(saved)
    ApiClient::Requests::Stash.write(api_request: saved, user:, attributes: { url: "https://edited.test" })
    described_class.call(api_requests: [saved], user:)

    expect(ApiClient::Requests::Stash.read(api_request: saved, user:)).to be_nil
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

  describe "edge cases" do
    it "does nothing for an empty list" do
      expect(described_class.call(api_requests: [], user:)).to be_success
    end

    it "does not close the tabs of other users", :aggregate_failures do
      other_tab = create(:request_tab, api_request: saved)
      open_tab(saved)
      described_class.call(api_requests: [saved], user:)

      expect(RequestTab.where(id: other_tab.id)).to exist
      expect(RequestTab.where(user:)).not_to exist
    end

    it "ignores requests without a tab", :aggregate_failures do
      expect(described_class.call(api_requests: [saved], user:)).to be_success
      expect(saved.reload).to be_persisted
    end
  end
end
