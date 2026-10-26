require "rails_helper"

RSpec.describe "Workbench folders" do
  include_context "with workbench project"

  describe "GET /workbench/collections/:collection_id/folders/new" do
    it "renders the form with a parent", :aggregate_failures do
      get new_workbench_collection_folder_path(collection, parent_id: folder.id)

      expect(response).to have_http_status(:ok)
    end

    it "does not find collections of other projects" do
      get new_workbench_collection_folder_path(foreign_collection)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /workbench/collections/:collection_id/folders" do
    it "creates a folder", :aggregate_failures do
      params = { folder: { name: "Users", auth_type: "bearer", auth_config: { token: "abc" } } }

      expect { post workbench_collection_folders_path(collection), params: }.to change(collection.folders, :count).by(1)
      expect(response).to redirect_to(workbench_root_path)
    end

    it "re-renders the modal when invalid" do
      post workbench_collection_folders_path(collection), params: { folder: { name: "" } }, headers: turbo_headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /workbench/folders/:id/edit" do
    it "renders the form" do
      get edit_workbench_folder_path(folder)

      expect(response).to have_http_status(:ok)
    end

    it "does not find folders of other projects" do
      get edit_workbench_folder_path(foreign_folder)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /workbench/folders/:id" do
    it "updates the folder", :aggregate_failures do
      patch workbench_folder_path(folder), params: { folder: { name: "Renamed" } }

      expect(response).to redirect_to(workbench_root_path)
      expect(folder.reload.name).to eq("Renamed")
    end

    it "re-renders the modal when invalid" do
      patch workbench_folder_path(folder), params: { folder: { name: "" } }, headers: turbo_headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /workbench/folders/:id" do
    it "destroys the folder", :aggregate_failures do
      folder
      expect { delete workbench_folder_path(folder) }.to change(Folder, :count).by(-1)
      expect(response).to redirect_to(workbench_root_path)
    end
  end

  describe "PATCH /workbench/folders/:id/position" do
    let(:parent) { create(:folder, collection:) }
    let(:sibling) { create(:folder, collection:) }

    it "moves the folder under a parent", :aggregate_failures do
      patch workbench_folder_position_path(folder), params: { parent_id: parent.id, before_id: "" }

      expect(response).to have_http_status(:no_content)
      expect(folder.reload.parent).to eq(parent)
    end

    it "reorders before a sibling", :aggregate_failures do
      folder
      patch workbench_folder_position_path(sibling), params: { before_id: folder.id }

      expect(response).to have_http_status(:no_content)
      expect(sibling.reload.position).to be < folder.reload.position
    end

    it "rejects moving a folder into itself" do
      patch workbench_folder_position_path(folder), params: { parent_id: folder.id }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "does not find folders of other projects" do
      patch workbench_folder_position_path(foreign_folder)

      expect(response).to have_http_status(:not_found)
    end
  end
end
