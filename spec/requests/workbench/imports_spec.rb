require "rails_helper"

RSpec.describe "Workbench imports" do
  include_context "with workbench project"

  def upload(name, type = "application/json")
    Rack::Test::UploadedFile.new(file_fixture("imports/#{name}"), type)
  end

  describe "GET /workbench/import/new" do
    it "renders the form" do
      get new_workbench_import_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("workbench.imports.form.apidog"))
    end
  end

  describe "POST /workbench/import" do
    it "imports an uploaded file into the current project", :aggregate_failures do
      expect { post workbench_import_path, params: { file: upload("postman_collection.json") } }.to change(project.collections, :count).by(1)

      expect(response).to redirect_to(workbench_root_path)
      expect(flash[:notice]).to include("1 collection", "1 folder", "15 requests", "1 environment")
      expect(flash[:notice]).to include("5 items need attention")
    end

    it "imports pasted content", :aggregate_failures do
      expect { post workbench_import_path, params: { content: file_fixture("imports/postman_environment.json").read } }.to change(project.environments, :count).by(1)

      expect(flash[:notice]).to eq("Imported 1 environment.")
    end

    it "reports a single warning in the singular" do
      content = { info: { name: "C" }, item: [{ name: "R", request: { url: "http://x", auth: { type: "hawk" } } }] }.to_json
      post workbench_import_path, params: { content: }

      expect(flash[:notice]).to include("1 item needs attention")
    end

    it "uploads YAML files" do
      post workbench_import_path, params: { file: upload("insomnia_v5.yaml", "application/x-yaml") }

      expect(project.collections.pluck(:name)).to eq(["Blog"])
    end

    it "shows the error for an empty submission", :aggregate_failures do
      post workbench_import_path, headers: turbo_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("workbench.imports.errors.empty"))
    end

    it "shows the error for an unknown format without creating anything", :aggregate_failures do
      expect { post workbench_import_path, params: { content: "{\"foo\":1}" }, headers: turbo_headers }.not_to change(Collection, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Format not recognized")
    end
  end
end
