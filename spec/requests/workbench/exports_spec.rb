require "rails_helper"

RSpec.describe "Workbench exports" do
  include_context "with workbench project"

  before do
    create(:api_request, collection:, name: "Ping", auth_type: "bearer", auth_config: { "token" => "tok-999" })
    environment = create(:environment, project:, name: "Prod")
    create(:variable, :secret, environment:, key: "KEY", value: "sekret")
  end

  describe "GET /workbench/collections/:collection_id/exports/new" do
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

  describe "POST /workbench/collections/:collection_id/exports" do
    it "queues the export and shows its progress", :aggregate_failures do
      expect { post workbench_collection_exports_path(collection), params: { format_name: "postman", include_environments: "1" } }.to have_enqueued_job(ExportCollectionJob)

      export = CollectionExport.last
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("progressbar").and include(workbench_export_path(export))
      expect(export).to have_attributes(user:, project:, collection:, export_format: "postman", include_environments: true, include_credentials: false)
    end

    it "does not build the file in the request", :aggregate_failures do
      post workbench_collection_exports_path(collection), params: { format_name: "shango" }

      expect(CollectionExport.last).to be_queued
      expect(CollectionExport.last.content).to be_nil
    end

    it "asks again for an unknown format", :aggregate_failures do
      expect { post workbench_collection_exports_path(collection), params: { format_name: "csv" } }.not_to change(CollectionExport, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("workbench.exports.errors.unknown_format"))
    end

    it "does not export collections of other projects" do
      post workbench_collection_exports_path(foreign_collection), params: { format_name: "shango" }

      expect(response).to have_http_status(:not_found)
    end

    it "is throttled", :aggregate_failures do
      allow(Throttling).to receive(:limit).and_call_original
      allow(Throttling).to receive(:limit).with(:exports).and_return([1, 1.minute])
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)

      2.times { post workbench_collection_exports_path(collection), params: { format_name: "shango" } }

      expect(response).to have_http_status(:see_other)
      expect(response.headers["Retry-After"]).to eq("60")
    end
  end

  describe "GET /workbench/exports/:id" do
    it "shows a queued export as a polling progress bar", :aggregate_failures do
      export = create(:collection_export, project:, user:, collection:, status: "running", progress: 45)

      get workbench_export_path(export)

      expect(response.body).to include('aria-valuenow="45"').and include('data-controller="poll"')
    end

    it "offers the download once done, without polling", :aggregate_failures do
      export = create(:collection_export, :done, project:, user:, collection:)

      get workbench_export_path(export)

      expect(response.body).to include(workbench_export_download_path(export)).and include("pets.shango.json")
      expect(response.body).not_to include("data-controller=\"poll\"")
    end

    it "explains a failure", :aggregate_failures do
      export = create(:collection_export, project:, user:, collection:, status: "failed", error: "unexpected")

      get workbench_export_path(export)

      expect(response.body).to include(I18n.t("workbench.exports.status.errors.unexpected"))
    end

    it "explains an expired export" do
      export = create(:collection_export, :done, project:, user:, collection:, expires_at: 1.minute.ago)

      get workbench_export_path(export)

      expect(response.body).to include(I18n.t("workbench.exports.status.expired"))
    end

    it "hides other members' exports" do
      get workbench_export_path(create(:collection_export, project:, collection:))

      expect(response).to have_http_status(:not_found)
    end

    it "hides exports of other projects" do
      get workbench_export_path(create(:collection_export, user:))

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /workbench/exports/:export_id/download" do
    it "sends the finished file", :aggregate_failures do
      export = create(:collection_export, :done, project:, user:, collection:)

      get workbench_export_download_path(export)

      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Disposition"]).to include("attachment").and include("pets.shango.json")
      expect(response.body).to eq('{"ok":true}')
    end

    it "downloads what the job built end to end", :aggregate_failures do
      post workbench_collection_exports_path(collection), params: { format_name: "shango", include_credentials: "1" }
      ExportCollectionJob.perform_now(user.id, CollectionExport.last.id)

      get workbench_export_download_path(CollectionExport.last)

      expect(response.body).to include("tok-999")
    end

    it "is gone until it is done and once it expires", :aggregate_failures do
      get workbench_export_download_path(create(:collection_export, project:, user:, collection:))
      expect(response).to have_http_status(:gone)

      get workbench_export_download_path(create(:collection_export, :done, project:, user:, collection:, expires_at: 1.minute.ago))
      expect(response).to have_http_status(:gone)
    end

    it "does not hand the file to other members" do
      get workbench_export_download_path(create(:collection_export, :done, project:, collection:))

      expect(response).to have_http_status(:not_found)
    end

    it "does not hand the file of other projects" do
      get workbench_export_download_path(create(:collection_export, :done, user:))

      expect(response).to have_http_status(:not_found)
    end
  end
end
