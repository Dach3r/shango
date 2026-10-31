require "rails_helper"

RSpec.describe "Workbench collections" do
  include_context "with workbench project"

  describe "GET /workbench/collections/new" do
    it "renders the form" do
      get new_workbench_collection_path

      expect(response).to have_http_status(:ok)
    end

    it "links back to the placement modal when opened from it", :aggregate_failures do
      get new_workbench_collection_path(draft_id: draft.id, placement: 1, request_name: "Login")

      expect(response.body).to include(new_workbench_request_placement_path(draft, request_name: "Login"))
      expect(response.body).to include(%(name="placement"), %(name="request_name" id="request_name" value="Login"))
    end
  end

  describe "POST /workbench/collections" do
    it "creates a collection", :aggregate_failures do
      expect { post workbench_collections_path, params: { collection: { name: "Payments", description: "x" } } }.to change(project.collections, :count).by(1)
      expect(response).to redirect_to(workbench_root_path)
      expect(project.collections.find_by!(name: "Payments").creator).to eq(user)
    end

    it "saves the originating draft into the new collection", :aggregate_failures do
      ApiClient::Drafts::Save.call(api_request: ApiClient::Drafts::Build.call(draft:), user:, attributes: { name: "Login", url: "https://api.example.com/login" })
      post workbench_collections_path, params: { collection: { name: "Payments" }, draft_id: draft.id }

      saved = project.api_requests.find_by!(name: "Login")
      expect(response).to redirect_to(workbench_request_path(saved))
      expect(saved.collection.name).to eq("Payments")
      expect(RequestDraft.where(id: draft.id)).not_to exist
    end

    it "returns to the placement modal with the new collection selected", :aggregate_failures do
      post workbench_collections_path, params: { collection: { name: "Payments" }, draft_id: draft.id, placement: 1, request_name: "Login" }

      created = project.collections.find_by!(name: "Payments")
      expect(response).to redirect_to(new_workbench_request_placement_path(draft, destination: "collection:#{created.id}", request_name: "Login"))
      expect(RequestDraft.where(id: draft.id)).to exist
    end

    it "keeps the draft open when it cannot be saved into the new collection", :aggregate_failures do
      allow(ApiClient::Drafts::Commit).to receive(:call).and_return(Result.failure)
      post workbench_collections_path, params: { collection: { name: "Payments" }, draft_id: draft.id }

      expect(response).to redirect_to(workbench_request_path(draft.id))
      expect(RequestDraft.where(id: draft.id)).to exist
    end

    it "keeps the draft in the form when invalid", :aggregate_failures do
      post workbench_collections_path, params: { collection: { name: "" }, draft_id: draft.id }, headers: turbo_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(%(name="draft_id" id="draft_id" value="#{draft.id}"))
    end

    it "re-renders the modal when invalid", :aggregate_failures do
      post workbench_collections_path, params: { collection: { name: "" } }, headers: turbo_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("turbo-stream")
    end
  end

  describe "GET /workbench/collections/:id/edit" do
    it "renders the form" do
      get edit_workbench_collection_path(collection)

      expect(response).to have_http_status(:ok)
    end

    it "does not find collections of other projects" do
      get edit_workbench_collection_path(foreign_collection)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /workbench/collections/:id" do
    it "saves the assertions and extractors every request in it inherits", :aggregate_failures do
      patch workbench_collection_path(collection), params: { collection: { name: "Same", assertions: { "0" => { source: "status", operator: "lt", expected: "500" } },
                                                                           extractors: { "0" => { source: "json", target: "$.t", variable: "t" } } } }

      expect(response).to redirect_to(workbench_root_path)
      expect(collection.reload.assertions).to contain_exactly(include("source" => "status", "operator" => "lt", "expected" => "500"))
      expect(collection.extractors).to contain_exactly(include("variable" => "t"))
    end

    it "saves the scripts every request in it inherits", :aggregate_failures do
      patch workbench_collection_path(collection), params: { collection: { name: "Same", pre_request_script: "// pre", post_response_script: "// post" } }

      expect(collection.reload).to have_attributes(pre_request_script: "// pre", post_response_script: "// post")
    end

    it "offers the tests section when editing, not when creating", :aggregate_failures do
      get edit_workbench_collection_path(collection), headers: turbo_headers
      expect(response.body).to include(I18n.t("workbench.automation.inherited.title"))

      get new_workbench_collection_path, headers: turbo_headers
      expect(response.body).not_to include(I18n.t("workbench.automation.inherited.title"))
    end

    it "updates the collection", :aggregate_failures do
      patch workbench_collection_path(collection), params: { collection: { name: "Renamed" } }

      expect(response).to redirect_to(workbench_root_path)
      expect(collection.reload.name).to eq("Renamed")
      expect(AuditEvent.sole).to have_attributes(kind: "collection_updated", actor: user)
    end

    it "re-renders the modal when invalid" do
      patch workbench_collection_path(collection), params: { collection: { name: "" } }, headers: turbo_headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /workbench/collections/:id" do
    it "destroys the collection", :aggregate_failures do
      collection
      expect { delete workbench_collection_path(collection) }.to change(Collection, :count).by(-1)
      expect(response).to redirect_to(workbench_root_path)
      expect(AuditEvent.sole).to have_attributes(kind: "collection_deleted", actor: user)
    end
  end

  describe "edge cases" do
    it "requires authentication", :aggregate_failures do
      sign_out user
      post workbench_collections_path, params: { collection: { name: "X" } }

      expect(response).to redirect_to(new_user_session_path)
      expect(Collection.where(name: "X")).not_to exist
    end

    it "rejects a missing collection param" do
      post workbench_collections_path

      expect(response).to have_http_status(:bad_request)
    end

    it "ignores attributes outside name and description", :aggregate_failures do
      other_project = create(:project)
      post workbench_collections_path, params: { collection: { name: "Safe", project_id: other_project.id, position: 99 } }

      created = Collection.find_by!(name: "Safe")
      expect(created.project).to eq(project)
      expect(created.position).to eq(1)
    end

    it "accepts unicode and duplicate names", :aggregate_failures do
      collection
      post workbench_collections_path, params: { collection: { name: collection.name } }
      post workbench_collections_path, params: { collection: { name: "日本語 🚀" } }

      expect(project.collections.pluck(:name)).to include("日本語 🚀")
      expect(project.collections.where(name: collection.name).count).to eq(2)
    end

    it "rejects a whitespace-only name" do
      post workbench_collections_path, params: { collection: { name: "   " } }, headers: turbo_headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "does not place drafts of other users" do
      post workbench_collections_path, params: { collection: { name: "Mine" }, draft_id: other_draft.id }

      expect(response).to have_http_status(:not_found)
    end

    it "does not place drafts of other projects" do
      foreign_draft = create(:request_draft, project: foreign_collection.project, user:)
      post workbench_collections_path, params: { collection: { name: "Mine" }, draft_id: foreign_draft.id }

      expect(response).to have_http_status(:not_found)
    end

    it "does not place a saved request through draft_id" do
      post workbench_collections_path, params: { collection: { name: "Mine" }, draft_id: api_request.id }

      expect(response).to have_http_status(:not_found)
    end

    it "does not update collections of other projects", :aggregate_failures do
      patch workbench_collection_path(foreign_collection), params: { collection: { name: "Hacked" } }

      expect(response).to have_http_status(:not_found)
      expect(foreign_collection.reload.name).not_to eq("Hacked")
    end

    it "does not destroy collections of other projects", :aggregate_failures do
      foreign_collection
      expect { delete workbench_collection_path(foreign_collection) }.not_to change(Collection, :count)
      expect(response).to have_http_status(:not_found)
    end

    it "treats a malformed id as not found" do
      get edit_workbench_collection_path("not-a-uuid")

      expect(response).to have_http_status(:not_found)
    end

    it "destroys nested folders, requests and tabs with the collection", :aggregate_failures do
      nested = create(:folder, collection:, parent: folder)
      request = create(:api_request, collection:, folder: nested)
      create(:request_tab, user:, api_request: request)

      delete workbench_collection_path(collection)

      expect(Folder.where(id: [folder.id, nested.id])).not_to exist
      expect(ApiRequest.where(id: request.id)).not_to exist
      expect(RequestTab.where(api_request_id: request.id)).not_to exist
    end
  end
end
