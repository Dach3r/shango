require "rails_helper"

RSpec.describe ApiClient::Drafts::Discard do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:api_request) { create(:api_request, project:) }

  it "discards the pending edits of a saved request and keeps the request", :aggregate_failures do
    create(:request_draft, :for_request, user:, api_request:, project:)

    expect(described_class.call(api_request:, user:)).to be_success
    expect(user.request_drafts).to be_empty
    expect(api_request.reload).to be_persisted
  end

  it "keeps the pending edits of other users" do
    other = create(:request_draft, :for_request, api_request:, project:)
    described_class.call(api_request:, user:)

    expect(RequestDraft.where(id: other.id)).to exist
  end

  it "discards a new draft with its tab", :aggregate_failures do
    draft = ApiClient::Drafts::Create.call(project:, user:).record
    described_class.call(api_request: ApiClient::Drafts::Build.call(draft:), user:)

    expect(RequestDraft.where(id: draft.id)).not_to exist
    expect(RequestTab.where(user:)).not_to exist
  end

  it "does not discard the draft of another user", :aggregate_failures do
    draft = create(:request_draft, project:)
    described_class.call(api_request: ApiClient::Drafts::Build.call(draft:), user:)

    expect(RequestDraft.where(id: draft.id)).to exist
  end

  it "is harmless when there is nothing to discard" do
    expect(described_class.call(api_request:, user:)).to be_success
  end
end
