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

    expect(response).to have_http_status(:unprocessable_entity)
  end
end
