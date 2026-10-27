require "rails_helper"

RSpec.describe "Workbench drafts" do
  include_context "with workbench project"

  let(:draft) { ApiClient::Requests::CreateDraft.call(project:, user:).record }

  describe "POST /workbench/drafts" do
    it "creates a draft and opens it", :aggregate_failures do
      expect { post workbench_drafts_path }.to change(project.api_requests.drafts, :count).by(1)

      expect(response).to redirect_to(workbench_request_path(project.api_requests.drafts.last))
    end
  end

  describe "GET /workbench/requests/:id" do
    it "renders the draft and lists it as a tab", :aggregate_failures do
      get workbench_request_path(draft)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(draft.name)
    end

    it "hides drafts of other users" do
      other = ApiClient::Requests::CreateDraft.call(project:, user: create(:user)).record
      get workbench_request_path(other)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /workbench/requests/:id" do
    it "asks where to save a draft", :aggregate_failures do
      collection
      patch workbench_request_path(draft), params: { place: 1, api_request: { name: "Renamed" } }, headers: turbo_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("placement_form")
      expect(draft.reload.name).to eq("Renamed")
    end
  end

  describe "GET /workbench/requests/:request_id/placement/new" do
    it "renders the form", :aggregate_failures do
      folder
      get new_workbench_request_placement_path(draft)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("folder:#{folder.id}")
    end

    it "asks for a collection first when there are none", :aggregate_failures do
      get new_workbench_request_placement_path(draft)

      expect(response.body).to include("collection_form")
      expect(response.body).to include(%(name="draft_id" id="draft_id" value="#{draft.id}"))
    end

    it "is not available for saved requests" do
      get new_workbench_request_placement_path(api_request)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /workbench/requests/:request_id/placement" do
    it "saves the draft into a collection", :aggregate_failures do
      patch workbench_request_placement_path(draft), params: { destination: "collection:#{collection.id}" }

      expect(response).to redirect_to(workbench_request_path(draft))
      expect(draft.reload).to have_attributes(collection:, user: nil)
    end

    it "saves the draft into a folder", :aggregate_failures do
      patch workbench_request_placement_path(draft), params: { destination: "folder:#{folder.id}" }

      expect(draft.reload).to have_attributes(collection:, folder:)
    end

    it "rejects destinations of other projects" do
      patch workbench_request_placement_path(draft), params: { destination: "collection:#{foreign_collection.id}" }

      expect(response).to have_http_status(:not_found)
    end

    it "re-renders the form when it cannot be saved", :aggregate_failures do
      allow(ApiClient::Requests::Place).to receive(:call).and_return(Result.failure(draft))
      patch workbench_request_placement_path(draft), params: { destination: "collection:#{collection.id}" }, headers: turbo_headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "edge cases" do
    it "requires authentication", :aggregate_failures do
      sign_out user

      expect { post workbench_drafts_path }.not_to change(ApiRequest, :count)
      expect(response).to redirect_to(new_user_session_path)
    end

    it "gives each draft its own tab and owner", :aggregate_failures do
      2.times { post workbench_drafts_path }

      expect(project.api_requests.drafts.pluck(:user_id).uniq).to eq([user.id])
      expect(RequestTab.where(user:).count).to eq(2)
    end

    it "does not offer placing drafts of other users" do
      other = ApiClient::Requests::CreateDraft.call(project:, user: create(:user)).record
      get new_workbench_request_placement_path(other)

      expect(response).to have_http_status(:not_found)
    end

    it "does not place into folders of other projects", :aggregate_failures do
      patch workbench_request_placement_path(draft), params: { destination: "folder:#{foreign_folder.id}" }

      expect(response).to have_http_status(:not_found)
      expect(draft.reload).to be_draft
    end

    it "does not place without a destination" do
      patch workbench_request_placement_path(draft)

      expect(response).to have_http_status(:not_found)
    end

    it "does not place saved requests" do
      patch workbench_request_placement_path(api_request), params: { destination: "collection:#{collection.id}" }

      expect(response).to have_http_status(:not_found)
    end

    it "places the draft last among the siblings of its destination", :aggregate_failures do
      existing = create(:api_request, collection:)
      patch workbench_request_placement_path(draft), params: { destination: "collection:#{collection.id}" }

      expect(draft.reload.position).to be > existing.position
    end

    it "does not let another user update a draft, even with place", :aggregate_failures do
      other = ApiClient::Requests::CreateDraft.call(project:, user: create(:user)).record
      patch workbench_request_path(other), params: { place: 1, api_request: { name: "Hacked" } }, headers: turbo_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
