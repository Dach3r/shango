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

  it "resolves response references for the user" do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    user = create(:user)
    source = create(:api_request, collection: api_request.collection)
    create(:request_execution, api_request: source, user:, response_body: '{"id":7}')
    api_request.update!(url: "https://api.test/items/{{response.body.#{source.id}.$.id}}")

    result = described_class.call(api_request:, environment: nil, user:)

    expect(result.data[:curl]).to include("'https://api.test/items/7'")
  end

  it "fails when the request cannot be built" do
    api_request.update!(url: "")

    result = described_class.call(api_request:, environment: nil)

    expect(result).to be_failure
    expect(result.error).to eq(I18n.t("workbench.errors.blank_url"))
  end
end
