require "rails_helper"

RSpec.describe "Workbench request stashes" do
  include_context "with workbench project"

  before { allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new) }

  def stashed
    ApiClient::Requests::Stash.read(api_request:, user:)
  end

  describe "PATCH /workbench/requests/:request_id/stash" do
    it "keeps the edits without touching the database", :aggregate_failures do
      patch workbench_request_stash_path(api_request), params: { api_request: { url: "https://edited.test", name: "Edited" } }

      expect(response).to have_http_status(:no_content)
      expect(stashed).to include("url" => "https://edited.test", "name" => "Edited")
      expect(api_request.reload.url).not_to eq("https://edited.test")
    end

    it "refuses an oversized state", :aggregate_failures do
      stub_const("ApiClient::Requests::Stash::MAX_BYTES", 10)
      patch workbench_request_stash_path(api_request), params: { api_request: { url: "https://edited.test" } }

      expect(response).to have_http_status(:content_too_large)
      expect(stashed).to be_nil
    end

    it "does not find requests of other projects" do
      patch workbench_request_stash_path(foreign_request), params: { api_request: { url: "x" } }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /workbench/requests/:request_id/stash" do
    it "discards the edits", :aggregate_failures do
      ApiClient::Requests::Stash.write(api_request:, user:, attributes: { url: "https://edited.test" })
      delete workbench_request_stash_path(api_request)

      expect(response).to redirect_to(workbench_request_path(api_request))
      expect(stashed).to be_nil
    end
  end

  describe "the request page" do
    it "restores the kept edits and offers to discard them", :aggregate_failures do
      ApiClient::Requests::Stash.write(api_request:, user:, attributes: { url: "https://edited.test", http_method: "PUT" })
      get workbench_request_path(api_request)

      expect(response.body).to include("https://edited.test", I18n.t("workbench.requests.unsaved_notice"), I18n.t("workbench.requests.discard_changes"))
      expect(api_request.reload.url).not_to eq("https://edited.test")
    end

    it "marks the tab of a saved request with kept edits" do
      get workbench_request_path(api_request)
      ApiClient::Requests::Stash.write(api_request:, user:, attributes: { url: "https://edited.test" })
      get workbench_request_path(api_request)

      expect(response.body).to include(I18n.t("components.request_tabs.unsaved_hint"))
    end

    it "shows the saved request when nothing is kept" do
      get workbench_request_path(api_request)

      expect(response.body).not_to include(I18n.t("workbench.requests.unsaved_notice"))
    end

    it "forgets the edits once the request is saved", :aggregate_failures do
      ApiClient::Requests::Stash.write(api_request:, user:, attributes: { url: "https://edited.test" })
      patch workbench_request_path(api_request), params: { api_request: { url: "https://saved.test" } }

      expect(stashed).to be_nil
    end

    it "keeps the edits when saving fails" do
      ApiClient::Requests::Stash.write(api_request:, user:, attributes: { url: "https://edited.test" })
      patch workbench_request_path(api_request), params: { api_request: { name: "" } }

      expect(stashed).not_to be_nil
    end

    it "forgets the edits once the request is deleted" do
      ApiClient::Requests::Stash.write(api_request:, user:, attributes: { url: "https://edited.test" })
      delete workbench_request_path(api_request)

      expect(stashed).to be_nil
    end
  end
end
