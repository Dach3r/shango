require "rails_helper"

RSpec.describe "ApiClient tabs" do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:first) { create(:api_request, project:, collection: create(:collection, project:)) }
  let(:second) { create(:api_request, project:, collection: first.collection) }

  describe ApiClient::Tabs::Open do
    it "opens a request once", :aggregate_failures do
      expect { 2.times { described_class.call(api_request: first, user:) } }.to change(RequestTab, :count).by(1)
      expect(described_class.call(api_request: first, user:)).to be_success
    end
  end

  describe ApiClient::Tabs::Close do
    it "closes only the user's tab", :aggregate_failures do
      other = create(:user)
      [user, other].each { |u| ApiClient::Tabs::Open.call(api_request: first, user: u) }

      described_class.call(api_request: first, user:)

      expect(RequestTab.pluck(:user_id)).to eq([other.id])
      expect(first.reload).to be_persisted
    end
  end

  describe ApiClient::Tabs::Load do
    it "lists the user's open requests in the order they were opened", :aggregate_failures do
      ApiClient::Tabs::Open.call(api_request: second, user:)
      ApiClient::Tabs::Open.call(api_request: first, user:)
      ApiClient::Tabs::Open.call(api_request: create(:api_request, project:, collection: first.collection), user: create(:user))

      expect(described_class.call(project:, user:)).to eq([second, first])
    end

    it "includes drafts" do
      draft = ApiClient::Drafts::Create.call(project:, user:).record

      expect(described_class.call(project:, user:).map(&:id)).to eq([draft.id])
    end
  end
end
