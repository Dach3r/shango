require "rails_helper"

RSpec.describe "Workbench request drafts" do
  include_context "with workbench project"

  def pending_edits
    user.request_drafts.find_by(api_request:)
  end

  describe "PATCH /workbench/requests/:request_id/draft" do
    it "keeps the edits of a saved request without touching it", :aggregate_failures do
      patch workbench_request_draft_path(api_request), params: { api_request: { url: "https://edited.test", name: "Edited" } }

      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty
      expect(pending_edits.data).to include("url" => "https://edited.test", "name" => "Edited")
      expect(api_request.reload.url).not_to eq("https://edited.test")
    end

    it "keeps a single draft per request, replacing the previous state", :aggregate_failures do
      patch workbench_request_draft_path(api_request), params: { api_request: { url: "https://one.test" } }
      patch workbench_request_draft_path(api_request), params: { api_request: { url: "https://two.test" } }

      expect(user.request_drafts.where(api_request:).count).to eq(1)
      expect(pending_edits.data["url"]).to eq("https://two.test")
    end

    it "refuses an oversized state", :aggregate_failures do
      stub_const("RequestDraft::MAX_BYTES", 10)
      patch workbench_request_draft_path(api_request), params: { api_request: { url: "https://edited.test" } }

      expect(response).to have_http_status(:content_too_large)
      expect(pending_edits).to be_nil
    end

    it "stores the payload encrypted", :aggregate_failures do
      patch workbench_request_draft_path(api_request), params: { api_request: { url: "https://edited.test", auth_type: "bearer", auth_config: { token: "s3cret" } } }

      raw = RequestDraft.connection.select_value("SELECT payload FROM request_drafts WHERE api_request_id = '#{api_request.id}'")
      expect(raw).not_to include("edited.test", "s3cret")
      expect(pending_edits.data["auth_config"]).to eq("token" => "s3cret")
    end

    it "limits how often a user can autosave", :aggregate_failures do
      stub_const("Throttling::LIMITS", Throttling::LIMITS.merge(drafts: [1, 1.minute]))
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      2.times { patch workbench_request_draft_path(api_request), params: { api_request: { url: "https://edited.test" } } }

      expect(response).to have_http_status(:too_many_requests)
    end

    it "does not find requests of other projects" do
      patch workbench_request_draft_path(foreign_request), params: { api_request: { url: "x" } }

      expect(response).to have_http_status(:not_found)
    end

    it "does not keep edits for other users' drafts", :aggregate_failures do
      patch workbench_request_draft_path(other_draft.id), params: { api_request: { url: "x" } }

      expect(response).to have_http_status(:not_found)
      expect(other_draft.reload.data).to eq({})
    end

    it "requires authentication" do
      sign_out user
      patch workbench_request_draft_path(api_request), params: { api_request: { url: "x" } }

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "DELETE /workbench/requests/:request_id/draft" do
    it "discards the pending edits", :aggregate_failures do
      create(:request_draft, :for_request, user:, api_request:, project:)
      delete workbench_request_draft_path(api_request)

      expect(response).to redirect_to(workbench_request_path(api_request))
      expect(pending_edits).to be_nil
    end
  end

  describe "the request page" do
    it "restores the kept edits and offers to discard them", :aggregate_failures do
      patch workbench_request_draft_path(api_request), params: { api_request: { url: "https://edited.test", http_method: "PUT" } }
      get workbench_request_path(api_request)

      expect(response.body).to include("https://edited.test", I18n.t("workbench.requests.unsaved_notice"), I18n.t("workbench.requests.discard_changes"))
      expect(api_request.reload.url).not_to eq("https://edited.test")
    end

    it "marks the tab of a saved request with kept edits" do
      get workbench_request_path(api_request)
      patch workbench_request_draft_path(api_request), params: { api_request: { url: "https://edited.test" } }
      get workbench_request_path(api_request)

      expect(response.body).to include(I18n.t("components.request_tabs.unsaved_hint"))
    end

    it "shows the saved request when nothing is kept" do
      get workbench_request_path(api_request)

      expect(response.body).not_to include(I18n.t("workbench.requests.unsaved_notice"))
    end

    it "forgets the edits once the request is saved", :aggregate_failures do
      patch workbench_request_draft_path(api_request), params: { api_request: { url: "https://edited.test" } }
      patch workbench_request_path(api_request), params: { api_request: { url: "https://saved.test" } }

      expect(api_request.reload.url).to eq("https://saved.test")
      expect(pending_edits).to be_nil
    end

    it "keeps the edits when saving fails" do
      patch workbench_request_draft_path(api_request), params: { api_request: { url: "https://edited.test" } }
      patch workbench_request_path(api_request), params: { api_request: { name: "" } }

      expect(pending_edits).not_to be_nil
    end

    it "forgets the edits once the request is deleted" do
      create(:request_draft, :for_request, user:, api_request:, project:)

      expect { delete workbench_request_path(api_request) }.to change(RequestDraft, :count).by(-1)
    end
  end
end
