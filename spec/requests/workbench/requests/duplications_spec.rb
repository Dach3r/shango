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
end
