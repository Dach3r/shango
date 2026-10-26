require "rails_helper"

RSpec.describe ApiClient::Requests::ExportCurl do
  let(:api_request) { create(:api_request, url: "{{host}}/items", http_method: "POST", body_type: "json", body: '{"a":1}') }
  let(:environment) { create(:environment, project: api_request.project) }

  it "renders the resolved request as curl" do
    create(:variable, environment:, key: "host", value: "https://api.test")

    result = described_class.call(api_request:, environment:)

    expect(result).to be_success
    expect(result.data[:curl]).to include("-X POST", "'https://api.test/items'", "--data-raw")
  end

  it "fails when the request cannot be built" do
    api_request.update!(url: "")

    result = described_class.call(api_request:, environment: nil)

    expect(result).to be_failure
    expect(result.error).to eq(I18n.t("workbench.errors.blank_url"))
  end
end
