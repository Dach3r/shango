require "rails_helper"

RSpec.describe ApiClient::Requests::Assign do
  let(:api_request) { create(:api_request, name: "Old", url: "https://old.test") }

  it "assigns the permitted attributes and auth without saving", :aggregate_failures do
    described_class.call(api_request:, attributes: { name: "New", url: "https://new.test", auth_type: "bearer", auth_config: { "token" => "abc" }, project_id: "x" })

    expect(api_request).to have_attributes(name: "New", url: "https://new.test", auth_type: "bearer", auth_config: { "token" => "abc" })
    expect(api_request.reload).to have_attributes(name: "Old", url: "https://old.test")
  end
end
