require "rails_helper"

RSpec.describe "Workbench curl imports" do
  include_context "with workbench project"

  describe "GET /workbench/collections/:collection_id/curl_import/new" do
    it "renders the form" do
      get new_workbench_collection_curl_import_path(collection)

      expect(response).to have_http_status(:ok)
    end

    it "does not find collections of other projects" do
      get new_workbench_collection_curl_import_path(foreign_collection)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /workbench/collections/:collection_id/curl_import" do
    it "imports the command as a request", :aggregate_failures do
      params = { command: "curl -X POST https://api.example.com/users -H 'Content-Type: application/json' -d '{\"a\":1}'", folder_id: folder.id }

      expect { post workbench_collection_curl_import_path(collection), params: }.to change(collection.api_requests, :count).by(1)
      expect(response).to redirect_to(workbench_request_path(collection.api_requests.last))
    end

    it "shows the parser error for an invalid command", :aggregate_failures do
      post workbench_collection_curl_import_path(collection), params: { command: "" }, headers: turbo_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "shows validation errors of the built request" do
      post workbench_collection_curl_import_path(collection), params: { command: "curl https://api.example.com", folder_id: foreign_folder.id }, headers: turbo_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
