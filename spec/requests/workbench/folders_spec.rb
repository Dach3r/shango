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

  describe "edge cases" do
    let(:parent) { create(:folder, collection:) }

    it "requires authentication", :aggregate_failures do
      sign_out user
      post workbench_collection_folders_path(collection), params: { folder: { name: "X" } }

      expect(response).to redirect_to(new_user_session_path)
      expect(Folder.where(name: "X")).not_to exist
    end

    it "does not create folders in collections of other projects", :aggregate_failures do
      expect { post workbench_collection_folders_path(foreign_collection), params: { folder: { name: "X" } } }.not_to change(Folder, :count)
      expect(response).to have_http_status(:not_found)
    end

    it "rejects a missing folder param" do
      post workbench_collection_folders_path(collection)

      expect(response).to have_http_status(:bad_request)
    end

    it "rejects a parent from another collection", :aggregate_failures do
      other = create(:folder, collection: create(:collection, project:))
      post workbench_collection_folders_path(collection), params: { folder: { name: "X", parent_id: other.id } }, headers: turbo_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(Folder.where(name: "X")).not_to exist
    end

    it "rejects a parent from another project" do
      post workbench_collection_folders_path(collection), params: { folder: { name: "X", parent_id: foreign_folder.id } }, headers: turbo_headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects a parent that does not exist" do
      post workbench_collection_folders_path(collection), params: { folder: { name: "X", parent_id: SecureRandom.uuid } }, headers: turbo_headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects an unknown auth type" do
      post workbench_collection_folders_path(collection), params: { folder: { name: "X", auth_type: "kerberos" } }, headers: turbo_headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "does not update folders of other projects", :aggregate_failures do
      patch workbench_folder_path(foreign_folder), params: { folder: { name: "Hacked" } }

      expect(response).to have_http_status(:not_found)
      expect(foreign_folder.reload.name).not_to eq("Hacked")
    end

    it "does not destroy folders of other projects", :aggregate_failures do
      foreign_folder
      expect { delete workbench_folder_path(foreign_folder) }.not_to change(Folder, :count)
      expect(response).to have_http_status(:not_found)
    end

    it "does not reparent through update", :aggregate_failures do
      patch workbench_folder_path(folder), params: { folder: { name: "Same", parent_id: parent.id } }

      expect(response).to redirect_to(workbench_root_path)
      expect(folder.reload.parent_id).to be_nil
    end

    it "destroys descendants and their requests", :aggregate_failures do
      child = create(:folder, collection:, parent: folder)
      request = create(:api_request, collection:, folder: child)

      delete workbench_folder_path(folder)

      expect(Folder.where(id: [folder.id, child.id])).not_to exist
      expect(ApiRequest.where(id: request.id)).not_to exist
    end

    describe "position" do
      it "rejects moving a folder into its own descendant", :aggregate_failures do
        child = create(:folder, collection:, parent: folder)
        grandchild = create(:folder, collection:, parent: child)
        patch workbench_folder_position_path(folder), params: { parent_id: grandchild.id }

        expect(response).to have_http_status(:unprocessable_content)
        expect(folder.reload.parent_id).to be_nil
      end

      it "does not find parents of another collection" do
        other = create(:folder, collection: create(:collection, project:))
        patch workbench_folder_position_path(folder), params: { parent_id: other.id }

        expect(response).to have_http_status(:not_found)
      end

      it "does not find parents of other projects" do
        patch workbench_folder_position_path(folder), params: { parent_id: foreign_folder.id }

        expect(response).to have_http_status(:not_found)
      end

      it "places the folder last when before_id is unknown", :aggregate_failures do
        sibling = create(:folder, collection:)
        patch workbench_folder_position_path(folder), params: { before_id: SecureRandom.uuid }

        expect(response).to have_http_status(:no_content)
        expect(folder.reload.position).to be > sibling.reload.position
      end

      it "ignores a before_id that is the folder itself", :aggregate_failures do
        folder
        sibling = create(:folder, collection:)
        patch workbench_folder_position_path(folder), params: { before_id: folder.id }

        expect(response).to have_http_status(:no_content)
        expect(folder.reload.position).to be > sibling.reload.position
      end

      it "orders against siblings of the new parent only", :aggregate_failures do
        root_sibling = create(:folder, collection:)
        inner = create(:folder, collection:, parent:)
        patch workbench_folder_position_path(folder), params: { parent_id: parent.id, before_id: root_sibling.id }

        expect(folder.reload.parent).to eq(parent)
        expect(folder.position).to be > inner.reload.position
      end

      it "requires authentication" do
        sign_out user
        patch workbench_folder_position_path(folder), params: { parent_id: parent.id }

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
