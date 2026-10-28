require "rails_helper"

RSpec.describe "Workbench request duplications" do
  include_context "with workbench project"

  it "duplicates the request", :aggregate_failures do
    api_request
    expect { post workbench_request_duplication_path(api_request) }.to change(ApiRequest, :count).by(1)
    expect(response).to redirect_to(workbench_request_path(ApiRequest.order(:created_at).last))
  end

  it "does not find requests of other projects" do
    post workbench_request_duplication_path(foreign_request)

    expect(response).to have_http_status(:not_found)
  end

  it "does not duplicate drafts of other users", :aggregate_failures do
    expect { post workbench_request_duplication_path(other_draft) }.not_to change(ApiRequest, :count)
    expect(response).to have_http_status(:not_found)
  end

  it "keeps the copy in the same folder, last among its siblings", :aggregate_failures do
    original = create(:api_request, collection:, folder:)
    post workbench_request_duplication_path(original)

    copy = ApiRequest.order(:created_at).last
    expect(copy).to have_attributes(folder:, collection:)
    expect(copy.position).to be > original.position
  end

  it "does not duplicate a draft that is not saved yet", :aggregate_failures do
    expect { post workbench_request_duplication_path(draft) }.not_to change(ApiRequest, :count)
    expect(response).to have_http_status(:forbidden).or have_http_status(:redirect)
  end

  it "requires authentication" do
    sign_out user
    post workbench_request_duplication_path(api_request)

    expect(response).to redirect_to(new_user_session_path)
  end
end
