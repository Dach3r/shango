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

  it "includes the user's own drafts" do
    draft = ApiClient::Requests::CreateDraft.call(project:, user:).record

    expect(described_class.call(project:, user:).map(&:id)).to eq([draft.id])
  end
end
