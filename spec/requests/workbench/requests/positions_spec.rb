require "rails_helper"

RSpec.describe "Workbench request positions" do
  include_context "with workbench project"

  it "moves the request into a folder before a sibling", :aggregate_failures do
    sibling = create(:api_request, collection:, folder:)
    patch workbench_request_position_path(api_request), params: { collection_id: collection.id, folder_id: folder.id, before_id: sibling.id }

    expect(response).to have_http_status(:no_content)
    expect(api_request.reload.folder).to eq(folder)
    expect(api_request.position).to be < sibling.reload.position
  end

  it "keeps the collection when none is given" do
    patch workbench_request_position_path(api_request), params: { folder_id: "" }

    expect(response).to have_http_status(:no_content)
  end

  it "rejects moves that make the request invalid" do
    patch workbench_request_position_path(api_request), params: { collection_id: collection.id, folder_id: create(:folder, collection: create(:collection, project:)).id }

    expect(response).to have_http_status(:not_found)
  end

  it "does not move into collections of other projects" do
    patch workbench_request_position_path(api_request), params: { collection_id: foreign_collection.id }

    expect(response).to have_http_status(:not_found)
  end

  it "fails with unprocessable entity when the save fails" do
    allow_any_instance_of(ApiRequest).to receive(:save).and_return(false) # rubocop:disable RSpec/AnyInstance
    patch workbench_request_position_path(api_request), params: { collection_id: collection.id }

    expect(response).to have_http_status(:unprocessable_content)
  end

  describe "edge cases" do
    let(:other_draft) { ApiClient::Requests::CreateDraft.call(project:, user: create(:user)).record }

    it "does not move requests of other projects", :aggregate_failures do
      patch workbench_request_position_path(foreign_request), params: { collection_id: collection.id }

      expect(response).to have_http_status(:not_found)
      expect(foreign_request.reload.collection).to eq(foreign_collection)
    end

    it "does not move drafts of other users" do
      patch workbench_request_position_path(other_draft), params: { collection_id: collection.id }

      expect(response).to have_http_status(:not_found)
    end

    it "does not find folders of other projects" do
      patch workbench_request_position_path(api_request), params: { collection_id: collection.id, folder_id: foreign_folder.id }

      expect(response).to have_http_status(:not_found)
    end

    it "places the request last when before_id is unknown or belongs to another collection", :aggregate_failures do
      sibling = create(:api_request, collection:)
      patch workbench_request_position_path(api_request), params: { before_id: SecureRandom.uuid }
      expect(api_request.reload.position).to be > sibling.reload.position

      patch workbench_request_position_path(sibling), params: { before_id: foreign_request.id }
      expect(sibling.reload.position).to be > api_request.reload.position
    end

    it "moves a request to the collection root", :aggregate_failures do
      in_folder = create(:api_request, collection:, folder:)
      patch workbench_request_position_path(in_folder), params: { folder_id: "" }

      expect(response).to have_http_status(:no_content)
      expect(in_folder.reload.folder).to be_nil
    end

    it "keeps positions contiguous across a reorder", :aggregate_failures do
      requests = create_list(:api_request, 3, collection:)
      patch workbench_request_position_path(requests.last), params: { before_id: requests.first.id }

      expect(collection.api_requests.order(:position).pluck(:id)).to eq([requests.last, requests.first, requests.second].map(&:id))
      expect(collection.api_requests.order(:position).pluck(:position)).to eq([1, 2, 3])
    end

    it "requires authentication" do
      sign_out user
      patch workbench_request_position_path(api_request), params: { collection_id: collection.id }

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
