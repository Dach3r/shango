require "rails_helper"

RSpec.describe "Workbench request closures" do
  include_context "with workbench project"

  let(:draft) { ApiClient::Requests::CreateDraft.call(project:, user:).record }

  it "asks what to do with a draft", :aggregate_failures do
    get new_workbench_request_closure_path(draft)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(CGI.escapeHTML(I18n.t("workbench.requests.closures.new.discard")), new_workbench_request_placement_path(draft))
  end

  it "does not find saved requests" do
    get new_workbench_request_closure_path(api_request)

    expect(response).to have_http_status(:not_found)
  end

  it "does not find drafts of other users" do
    other = ApiClient::Requests::CreateDraft.call(project:, user: create(:user)).record
    get new_workbench_request_closure_path(other)

    expect(response).to have_http_status(:not_found)
  end

  it "does not find requests of other projects" do
    get new_workbench_request_closure_path(foreign_request)

    expect(response).to have_http_status(:not_found)
  end
end
