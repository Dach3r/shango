require "rails_helper"

RSpec.describe "Workbench exports" do
  include_context "with workbench project"

  before do
    create(:api_request, collection:, name: "Ping", auth_type: "bearer", auth_config: { "token" => "tok-999" })
    environment = create(:environment, project:, name: "Prod")
    create(:variable, :secret, environment:, key: "KEY", value: "sekret")
  end

  describe "GET /workbench/collections/:collection_id/export/new" do
    it "renders the form", :aggregate_failures do
      get new_workbench_collection_export_path(collection)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("format_name").and include("include_credentials")
    end

    it "is open to members who did not create the collection" do
      get new_workbench_collection_export_path(create(:collection, project:, creator: create(:user)))

      expect(response).to have_http_status(:ok)
    end

    it "does not find collections of other projects" do
      get new_workbench_collection_export_path(foreign_collection)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /workbench/collections/:collection_id/export" do
    it "downloads the collection in the chosen format", :aggregate_failures do
      post workbench_collection_export_path(collection), params: { format_name: "postman" }

      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Disposition"]).to include("attachment").and include(".postman_collection.json")
      expect(JSON.parse(response.body).dig("info", "name")).to eq(collection.name)
    end

    it "leaves credentials out unless asked", :aggregate_failures do
      post workbench_collection_export_path(collection), params: { format_name: "shango", include_environments: "1" }
      expect(response.body).not_to include("tok-999", "sekret")

      post workbench_collection_export_path(collection), params: { format_name: "shango", include_environments: "1", include_credentials: "1" }
      expect(response.body).to include("tok-999", "sekret")
    end

    it "sends a ZIP when Postman environments come along", :aggregate_failures do
      post workbench_collection_export_path(collection), params: { format_name: "postman", include_environments: "1" }

      expect(response.media_type).to eq("application/zip")
      expect(response.headers["Content-Disposition"]).to include(".zip")
    end

    it "sends the user back for an unknown format", :aggregate_failures do
      post workbench_collection_export_path(collection), params: { format_name: "csv" }

      expect(response).to redirect_to(workbench_root_path)
      expect(flash[:alert]).to eq(I18n.t("workbench.exports.errors.unknown_format"))
    end

    it "does not export collections of other projects" do
      post workbench_collection_export_path(foreign_collection), params: { format_name: "shango" }

      expect(response).to have_http_status(:not_found)
    end

    it "is throttled", :aggregate_failures do
      allow(Throttling).to receive(:limit).and_call_original
      allow(Throttling).to receive(:limit).with(:exports).and_return([1, 1.minute])
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)

      2.times { post workbench_collection_export_path(collection), params: { format_name: "shango" } }

      expect(response).to have_http_status(:see_other)
      expect(response.headers["Retry-After"]).to eq("60")
    end
  end
end
