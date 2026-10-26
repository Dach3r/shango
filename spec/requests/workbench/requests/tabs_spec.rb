require "rails_helper"

RSpec.describe "Workbench request tabs" do
  include_context "with workbench project"

  let(:other_request) { create(:api_request, collection:) }

  before do
    get workbench_request_path(api_request)
    get workbench_request_path(other_request)
  end

  it "opens a tab when a request is shown", :aggregate_failures do
    expect(RequestTab.where(user:).count).to eq(2)
    expect(response.body).to include(workbench_request_tab_path(api_request))
  end

  it "closes a background tab and stays on the page", :aggregate_failures do
    delete workbench_request_tab_path(api_request)

    expect(response).to redirect_to(workbench_root_path)
    expect(RequestTab.where(user:, api_request:)).not_to exist
    expect(api_request.reload).to be_persisted
  end

  it "moves to the last open tab when closing the current one" do
    delete workbench_request_tab_path(other_request, current: true)

    expect(response).to redirect_to(workbench_request_path(api_request))
  end

  it "goes back to the workbench when no tabs remain" do
    delete workbench_request_tab_path(api_request)
    delete workbench_request_tab_path(other_request, current: true)

    expect(response).to redirect_to(workbench_root_path)
  end

  it "does not close tabs of requests from other projects" do
    delete workbench_request_tab_path(foreign_request)

    expect(response).to have_http_status(:not_found)
  end
end
