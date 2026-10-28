require "rails_helper"

RSpec.describe ApiClient::Tabs::Load do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:collection) { create(:collection, project:) }

  it "lists the user's open requests oldest tab first", :aggregate_failures do
    first = create(:api_request, collection:)
    second = create(:api_request, collection:)
    create(:request_tab, user:, api_request: second, created_at: 2.minutes.ago)
    create(:request_tab, user:, api_request: first, created_at: 1.minute.ago)

    expect(described_class.call(project:, user:).map(&:id)).to eq([second.id, first.id])
  end

  it "excludes other users' tabs and other projects' requests", :aggregate_failures do
    create(:request_tab, api_request: create(:api_request, collection:))
    create(:request_tab, user:, api_request: create(:api_request))

    expect(described_class.call(project:, user:)).to eq([])
  end

  it "includes the user's own drafts as in-memory requests", :aggregate_failures do
    draft = ApiClient::Drafts::Create.call(project:, user:).record
    ApiClient::Drafts::Save.call(api_request: ApiClient::Drafts::Build.call(draft:), user:, attributes: { http_method: "POST", name: "Login" })

    tab = described_class.call(project:, user:).first

    expect(tab).to have_attributes(id: draft.id, name: "Login", http_method: "POST", draft_owner_id: user.id)
    expect(tab).to be_draft.and(be_new_record)
  end

  it "orders saved requests and drafts by when their tab was opened", :aggregate_failures do
    saved = create(:api_request, collection:)
    create(:request_tab, user:, api_request: saved, created_at: 2.minutes.ago)
    draft = ApiClient::Drafts::Create.call(project:, user:).record
    create(:request_draft, project:, user: create(:user)).tap { |other| create(:request_tab, user: other.user, api_request: nil, request_draft: other) }

    expect(described_class.call(project:, user:).map(&:id)).to eq([saved.id, draft.id])
  end

  it "carries what the tabs need to check permissions without more queries", :aggregate_failures do
    create(:request_tab, user:, api_request: create(:api_request, collection:))
    tab = described_class.call(project:, user:).first

    expect(tab).to have_attributes(collection_id: collection.id)
    expect(count_queries { tab.collection.creator_id }).to eq(0)
  end
end
