require "rails_helper"

RSpec.describe "Draft requests" do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:collection) { create(:collection, project:) }

  describe ApiClient::Requests::CreateDraft do
    it "creates a request owned by the user without a collection", :aggregate_failures do
      result = described_class.call(project:, user:)

      expect(result).to be_success
      expect(result.record).to be_draft
      expect(result.record).to have_attributes(project:, user:, collection: nil)
    end
  end

  describe ApiClient::Requests::Place do
    it "moves a draft into a collection and releases the owner", :aggregate_failures do
      draft = ApiClient::Requests::CreateDraft.call(project:, user:).record
      folder = create(:folder, collection:)

      result = described_class.call(api_request: draft, collection:, folder:)

      expect(result).to be_success
      expect(draft.reload).to have_attributes(collection:, folder:, user: nil, project:)
    end
  end

  describe ApiRequest do
    it "shows drafts only to their owner" do
      draft = ApiClient::Requests::CreateDraft.call(project:, user:).record
      saved = create(:api_request, collection:)

      expect(project.api_requests.visible_to(user)).to contain_exactly(draft, saved)
      expect(project.api_requests.visible_to(create(:user))).to contain_exactly(saved)
    end

    it "requires an owner when it has no collection" do
      expect(project.api_requests.new(name: "x")).not_to be_valid
    end
  end

  describe ApiClient::Requests::Place, "with a folder of another collection" do
    it "fails and keeps the draft" do
      draft = ApiClient::Requests::CreateDraft.call(project:, user:).record

      result = described_class.call(api_request: draft, collection:, folder: create(:folder))

      expect(result).to be_failure
    end
  end

  describe ApiClient::Requests::Move do
    it "releases the owner when a draft is dragged into a collection" do
      draft = ApiClient::Requests::CreateDraft.call(project:, user:).record

      described_class.call(api_request: draft, collection_id: collection.id)

      expect(draft.reload).to have_attributes(collection:, user: nil)
    end
  end

  describe ApiClient::Tree::LoadDrafts do
    it "lists only the user's drafts" do
      mine = ApiClient::Requests::CreateDraft.call(project:, user:).record
      ApiClient::Requests::CreateDraft.call(project:, user: create(:user))

      expect(described_class.call(project:, user:)).to eq([mine])
    end
  end

  describe ApiClient::Auth::EffectiveAuth do
    it "sends no authorization for a draft that inherits" do
      draft = ApiClient::Requests::CreateDraft.call(project:, user:).record

      expect(described_class.call(api_request: draft)).to have_attributes(type: "none", owner: nil)
    end
  end
end
