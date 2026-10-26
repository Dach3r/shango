require "rails_helper"

RSpec.describe ApiClient::Requests::Update do
  let(:api_request) { create(:api_request, name: "Old") }

  it "updates the permitted attributes", :aggregate_failures do
    result = described_class.call(api_request:, attributes: { name: "New", http_method: "POST", auth_type: "bearer", auth_config: { "token" => "abc" }, project_id: "x" })

    expect(result).to be_success
    expect(api_request.reload).to have_attributes(name: "New", http_method: "POST", auth_type: "bearer", project: api_request.collection.project)
  end

  it "fails when the request is invalid" do
    expect(described_class.call(api_request:, attributes: { name: "" })).to be_failure
  end
end
