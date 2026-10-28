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

  it "forgets the pending edits of the request" do
    create(:request_draft, :for_request, user:, api_request:, project: api_request.project)

    expect { described_class.call(api_request:, user:) }.to change(RequestDraft, :count).by(-1)
  end

  it "drops the unsaved response of the request, not those of others", :aggregate_failures do
    build(:request_execution, id: SecureRandom.uuid, api_request:, user:).stash
    build(:request_execution, id: SecureRandom.uuid, api_request:, user: create(:user)).stash
    build(:request_execution, id: SecureRandom.uuid, api_request: create(:api_request), user:).stash

    expect { described_class.call(api_request:, user:) }.to change(LatestExecution, :count).by(-1)
    expect(RequestExecution.unsaved_for(api_request, user)).to be_nil
  end

  it "discards a new draft with its tab", :aggregate_failures do
    project = create(:project)
    draft = ApiClient::Drafts::Create.call(project:, user:).record

    expect { described_class.call(api_request: ApiClient::Drafts::Build.call(draft:), user:) }.to change(RequestDraft, :count).by(-1)
    expect(RequestTab.where(user:)).not_to exist
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
