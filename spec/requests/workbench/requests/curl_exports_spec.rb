require "rails_helper"

RSpec.describe "Workbench request curl exports" do
  include_context "with workbench project"

  it "returns the curl command", :aggregate_failures do
    get workbench_request_curl_export_path(api_request)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["curl"]).to include("curl", api_request.url)
  end

  it "resolves variables of the selected environment" do
    environment = create(:environment, project:)
    create(:variable, environment:, key: "HOST", value: "api.example.com")
    membership.update!(current_environment: environment)
    api_request.update!(url: "https://{{HOST}}/x")
    get workbench_request_curl_export_path(api_request)

    expect(response.parsed_body["curl"]).to include("https://api.example.com/x")
  end

  it "returns the error when the request cannot be built", :aggregate_failures do
    api_request.update!(url: "ftp://example.com")
    get workbench_request_curl_export_path(api_request)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body["error"]).to be_present
  end
end
