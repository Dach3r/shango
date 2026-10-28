require "rails_helper"

RSpec.describe ApiClient::Tabs::CloseMany do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:saved) { create(:api_request, project:) }

  def open_tab(api_request)
    ApiClient::Tabs::Open.call(api_request:, user:)
    api_request
  end

  def open_draft
    ApiClient::Drafts::Build.call(draft: ApiClient::Drafts::Create.call(project:, user:).record)
  end

  it "forgets the pending edits of the closed tabs" do
    open_tab(saved)
    create(:request_draft, :for_request, user:, api_request: saved, project:)

    expect { described_class.call(api_requests: [saved], user:) }.to change(RequestDraft, :count).by(-1)
  end

  it "closes saved tabs without deleting the requests", :aggregate_failures do
    open_tab(saved)

    described_class.call(api_requests: [saved], user:)

    expect(RequestTab.where(user:)).not_to exist
    expect(saved.reload).to be_persisted
  end

  it "discards untouched drafts" do
    draft = open_draft

    expect { described_class.call(api_requests: [draft], user:) }.to change(RequestDraft, :count).by(-1)
  end

  it "discards drafts with edits too, since the caller confirmed them" do
    draft = open_draft
    ApiClient::Drafts::Save.call(api_request: draft, user:, attributes: { name: "Edited" })

    expect { described_class.call(api_requests: [draft], user:) }.to change(RequestDraft, :count).by(-1)
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
