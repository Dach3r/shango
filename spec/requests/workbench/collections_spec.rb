require "rails_helper"

RSpec.describe "Workbench collections" do
  include_context "with workbench project"

  describe "GET /workbench/collections/new" do
    it "renders the form" do
      get new_workbench_collection_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /workbench/collections" do
    it "creates a collection", :aggregate_failures do
      expect { post workbench_collections_path, params: { collection: { name: "Payments", description: "x" } } }.to change(project.collections, :count).by(1)
      expect(response).to redirect_to(workbench_root_path)
    end

    it "re-renders the modal when invalid", :aggregate_failures do
      post workbench_collections_path, params: { collection: { name: "" } }, headers: turbo_headers

      expect(response).to have_http_status(:unprocessable_entity)
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
    it "updates the collection", :aggregate_failures do
      patch workbench_collection_path(collection), params: { collection: { name: "Renamed" } }

      expect(response).to redirect_to(workbench_root_path)
      expect(collection.reload.name).to eq("Renamed")
    end

    it "re-renders the modal when invalid" do
      patch workbench_collection_path(collection), params: { collection: { name: "" } }, headers: turbo_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /workbench/collections/:id" do
    it "destroys the collection", :aggregate_failures do
      collection
      expect { delete workbench_collection_path(collection) }.to change(Collection, :count).by(-1)
      expect(response).to redirect_to(workbench_root_path)
    end
  end
end
