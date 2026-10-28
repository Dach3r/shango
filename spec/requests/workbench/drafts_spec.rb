require "rails_helper"

RSpec.describe "Workbench drafts" do
  include_context "with workbench project"

  def save_draft(attributes)
    ApiClient::Drafts::Save.call(api_request: ApiClient::Drafts::Build.call(draft:), user:, attributes:)
  end

  describe "POST /workbench/drafts" do
    it "opens a draft without writing a request", :aggregate_failures do
      expect { post workbench_drafts_path }.to change(project.request_drafts, :count).by(1)

      expect(ApiRequest.count).to eq(0)
      expect(response).to redirect_to(workbench_request_path(project.request_drafts.last.id))
      expect(RequestTab.where(user:, request_draft: project.request_drafts.last)).to exist
    end

    it "gives each draft its own tab and owner", :aggregate_failures do
      2.times { post workbench_drafts_path }

      expect(project.request_drafts.pluck(:user_id).uniq).to eq([user.id])
      expect(RequestTab.where(user:).count).to eq(2)
    end

    it "requires authentication", :aggregate_failures do
      sign_out user

      expect { post workbench_drafts_path }.not_to change(RequestDraft, :count)
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "GET /workbench/requests/:id" do
    it "renders the draft and lists it as a tab", :aggregate_failures do
      get workbench_request_path(draft.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(draft.name, workbench_request_draft_path(draft.id))
    end

    it "renders what was autosaved", :aggregate_failures do
      save_draft(url: "https://api.example.com/kept", http_method: "POST")
      get workbench_request_path(draft.id)

      expect(response.body).to include("https://api.example.com/kept")
      expect(response.body).not_to include(I18n.t("workbench.requests.unsaved_notice"))
    end

    it "does not offer to save the response of a draft" do
      stub_request(:get, "https://api.example.com/new").to_return(status: 200, body: "ok")
      post workbench_request_executions_path(draft.id), params: { api_request: { url: "https://api.example.com/new" } }, headers: turbo_headers

      expect(response.body).to include("200").and(satisfy { |body| body.exclude?("/saves") })
    end

    it "hides drafts of other users" do
      get workbench_request_path(other_draft.id)

      expect(response).to have_http_status(:not_found)
    end

    it "hides drafts of other projects" do
      get workbench_request_path(create(:request_draft, user:).id)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /workbench/requests/:id" do
    it "keeps the edits as the draft and asks where to save, without writing a request", :aggregate_failures do
      collection
      expect do
        patch workbench_request_path(draft.id), params: { place: 1, api_request: { name: "Renamed" } }, headers: turbo_headers
      end.not_to change(ApiRequest, :count)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("placement_form")
      expect(draft.reload).to have_attributes(name: "Renamed")
    end

    it "refuses a draft that is too large", :aggregate_failures do
      stub_const("RequestDraft::MAX_BYTES", 10)
      patch workbench_request_path(draft.id), params: { place: 1, api_request: { name: "Renamed", url: "https://api.example.com/long" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("activerecord.errors.models.api_request.attributes.base.draft_too_large"))
    end

    it "does not let another user update a draft, even with place", :aggregate_failures do
      patch workbench_request_path(other_draft.id), params: { place: 1, api_request: { name: "Hacked" } }, headers: turbo_headers

      expect(response).to have_http_status(:not_found)
      expect(other_draft.reload.name).not_to eq("Hacked")
    end
  end

  describe "DELETE /workbench/requests/:id" do
    it "discards the draft and its tab", :aggregate_failures do
      draft
      expect { delete workbench_request_path(draft.id) }.to change(RequestDraft, :count).by(-1)

      expect(response).to redirect_to(workbench_root_path)
      expect(RequestTab.where(user:)).not_to exist
    end
  end

  describe "PATCH /workbench/requests/:request_id/settings" do
    it "keeps the settings in the draft", :aggregate_failures do
      patch workbench_request_settings_path(draft.id), params: { api_request: { settings: { timeout: "7" } } }

      expect(response).to have_http_status(:no_content)
      expect(draft.reload.data["settings"]).to include("timeout" => "7")
    end

    it "keeps settings the autosave does not send", :aggregate_failures do
      patch workbench_request_settings_path(draft.id), params: { api_request: { settings: { timeout: "7" } } }
      patch workbench_request_draft_path(draft.id), params: { api_request: { url: "https://api.example.com/x" } }

      expect(draft.reload.data).to include("url" => "https://api.example.com/x", "settings" => include("timeout" => "7"))
    end
  end

  describe "GET /workbench/requests/:request_id/placement/new" do
    it "lists the collections with the draft name to start from", :aggregate_failures do
      folder
      get new_workbench_request_placement_path(draft.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(collection.name, "destination=collection%3A#{collection.id}", %(value="#{draft.name}"))
      expect(response.body).not_to include(folder.name)
      expect(response.body).to include("disabled")
    end

    it "browses into a collection and its folders keeping the typed name", :aggregate_failures do
      child = create(:folder, collection:, parent: folder)
      get new_workbench_request_placement_path(draft.id, destination: "folder:#{folder.id}", request_name: "Login")

      expect(response.body).to include(child.name, "destination=folder%3A#{child.id}", %(value="Login"))
      expect(response.body).to match(/name="destination" value="folder:#{folder.id}"/)
      expect(response.body).to include(new_workbench_collection_folder_path(collection, parent_id: folder.id, draft_id: draft.id, placement: 1, request_name: "Login").gsub("&", "&amp;"))
    end

    it "says when a collection has no folders" do
      get new_workbench_request_placement_path(draft.id, destination: "collection:#{collection.id}")

      expect(response.body).to include(I18n.t("workbench.requests.placements.form.no_folders"))
    end

    it "does not browse into other projects" do
      get new_workbench_request_placement_path(draft.id, destination: "collection:#{foreign_collection.id}")

      expect(response).to have_http_status(:not_found)
    end

    it "asks for a collection first when there are none", :aggregate_failures do
      get new_workbench_request_placement_path(draft.id)

      expect(response.body).to include("collection_form")
      expect(response.body).to include(%(name="draft_id" id="draft_id" value="#{draft.id}"))
    end

    it "is not available for saved requests" do
      get new_workbench_request_placement_path(api_request)

      expect(response).to have_http_status(:not_found)
    end

    it "does not offer placing drafts of other users" do
      get new_workbench_request_placement_path(other_draft.id)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /workbench/requests/:request_id/placement" do
    before { save_draft(name: "Login", url: "https://api.example.com/login", http_method: "POST", auth_type: "bearer", auth_config: { token: "s3cret" }) }

    it "saves the draft as a request of the collection", :aggregate_failures do
      expect { patch workbench_request_placement_path(draft.id), params: { destination: "collection:#{collection.id}", request_name: "Login" } }.to change(ApiRequest, :count).by(1)

      saved = collection.api_requests.find_by!(name: "Login")
      expect(response).to redirect_to(workbench_request_path(saved))
      expect(saved).to have_attributes(url: "https://api.example.com/login", http_method: "POST", auth_type: "bearer", folder: nil)
      expect(saved.auth_config).to include("token" => "s3cret")
    end

    it "consumes the draft and moves its tab to the saved request", :aggregate_failures do
      patch workbench_request_placement_path(draft.id), params: { destination: "collection:#{collection.id}", request_name: "Login" }
      saved = collection.api_requests.find_by!(name: "Login")

      expect(RequestDraft.where(id: draft.id)).not_to exist
      expect(RequestTab.where(user:).pluck(:api_request_id, :request_draft_id)).to eq([[saved.id, nil]])
    end

    it "saves it under the name typed in the dialog" do
      patch workbench_request_placement_path(draft.id), params: { destination: "collection:#{collection.id}", request_name: "  Sign in " }

      expect(collection.api_requests.find_by(name: "Sign in")).to be_present
    end

    it "asks for a name when it is blank", :aggregate_failures do
      expect { patch workbench_request_placement_path(draft.id), params: { destination: "folder:#{folder.id}", request_name: " " }, headers: turbo_headers }.not_to change(ApiRequest, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(RequestDraft.where(id: draft.id)).to exist
    end

    it "saves the draft into a folder", :aggregate_failures do
      patch workbench_request_placement_path(draft.id), params: { destination: "folder:#{folder.id}", request_name: "Login" }

      expect(project.api_requests.find_by!(name: "Login")).to have_attributes(collection:, folder:)
    end

    it "places the draft last among the siblings of its destination" do
      existing = create(:api_request, collection:)
      patch workbench_request_placement_path(draft.id), params: { destination: "collection:#{collection.id}", request_name: "Login" }

      expect(project.api_requests.find_by!(name: "Login").position).to be > existing.position
    end

    it "rejects destinations of other projects", :aggregate_failures do
      expect { patch workbench_request_placement_path(draft.id), params: { destination: "collection:#{foreign_collection.id}" } }.not_to change(ApiRequest, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "does not place into folders of other projects", :aggregate_failures do
      patch workbench_request_placement_path(draft.id), params: { destination: "folder:#{foreign_folder.id}" }

      expect(response).to have_http_status(:not_found)
      expect(RequestDraft.where(id: draft.id)).to exist
    end

    it "does not place without a destination" do
      patch workbench_request_placement_path(draft.id)

      expect(response).to have_http_status(:not_found)
    end

    it "does not place saved requests" do
      patch workbench_request_placement_path(api_request), params: { destination: "collection:#{collection.id}", request_name: "Login" }

      expect(response).to have_http_status(:not_found)
    end

    it "does not place drafts of other users" do
      patch workbench_request_placement_path(other_draft.id), params: { destination: "collection:#{collection.id}", request_name: "Login" }

      expect(response).to have_http_status(:not_found)
    end

    it "re-renders the form and keeps the draft when it cannot be saved", :aggregate_failures do
      save_draft(name: "")
      allow(ApiClient::Drafts::Commit).to receive(:call).and_return(Result.failure(ApiRequest.new.tap { |request| request.errors.add(:name, :blank) }))
      patch workbench_request_placement_path(draft.id), params: { destination: "collection:#{collection.id}", request_name: "Login" }, headers: turbo_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(RequestDraft.where(id: draft.id)).to exist
    end
  end
end
