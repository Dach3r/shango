require "rails_helper"

RSpec.describe ApiClient::Requests::Run do
  let(:project) { create(:project) }
  let(:collection) { create(:collection, project:) }
  let(:api_request) { create(:api_request, collection:, url: "https://api.example.com/items") }
  let(:user) { create(:user) }
  let(:environment) { create(:environment, project:) }
  let(:attributes) { {} }
  let(:result) { described_class.call(api_request:, environment:, user:, attributes:) }
  let(:execution) { result.record }

  it "records the execution", :aggregate_failures do
    stub_request(:get, api_request.url).to_return(status: 200, body: "hello", headers: { "Content-Type" => "text/plain" })

    expect(result).to be_success
    expect(execution).to have_attributes(
      http_method: "GET", url: api_request.url, status: 200, status_text: "OK", response_body: "hello", content_type: "text/plain", size_bytes: 5,
      body_omitted: false, body_truncated: false, error_kind: nil, user:, environment:, project:, api_request:, redirects: []
    )
  end

  it "masks secrets in everything stored", :aggregate_failures do
    create(:variable, :secret, environment:, key: "token", value: "supersecret")
    api_request.update!(headers: [{ "key" => "X-Token", "value" => "{{token}}" }, { "key" => "Authorization", "value" => "Bearer abc" }])
    stub_request(:get, api_request.url).to_return(status: 302, body: "echo supersecret", headers: { "Location" => "/next?t=supersecret", "Content-Type" => "text/plain" })
    stub_request(:get, "https://api.example.com/next?t=supersecret").to_return(status: 200, body: "echo supersecret")

    expect(execution.response_body).to eq("echo #{ApiClient::Masker::MASK}")
    expect(execution.request_headers).to include(["X-Token", ApiClient::Masker::MASK], ["Authorization", ApiClient::Masker::MASK])
    expect(execution.redirects).to contain_exactly(include("status" => 302, "to" => "https://api.example.com/next?t=#{ApiClient::Masker::MASK}"))
  end

  it "stores a blank body" do
    stub_request(:get, api_request.url).to_return(status: 204)

    expect(execution).to have_attributes(response_body: "", body_omitted: false)
  end

  it "stores bodies without content type as text" do
    stub_request(:get, api_request.url).to_return(status: 200, body: "plain")

    expect(execution.response_body).to eq("plain")
  end

  it "omits binary bodies", :aggregate_failures do
    stub_request(:get, api_request.url).to_return(status: 200, body: "\x89PNG\x00".b, headers: { "Content-Type" => "image/png" })

    expect(execution).to have_attributes(response_body: nil, body_omitted: true)
  end

  it "omits bodies that are not valid UTF-8" do
    stub_request(:get, api_request.url).to_return(status: 200, body: "\xFF\xFE".b, headers: { "Content-Type" => "text/plain" })

    expect(execution.body_omitted).to be(true)
  end

  it "omits text bodies with null bytes" do
    stub_request(:get, api_request.url).to_return(status: 200, body: "a\u0000b", headers: { "Content-Type" => "text/plain" })

    expect(execution.body_omitted).to be(true)
  end

  it "omits non-text content types" do
    stub_request(:get, api_request.url).to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/octet-stream" })

    expect(execution.body_omitted).to be(true)
  end

  it "truncates stored bodies over the limit", :aggregate_failures do
    stub_request(:get, api_request.url).to_return(status: 200, body: "a" * (described_class::BODY_LIMIT + 10), headers: { "Content-Type" => "text/plain" })

    expect(execution.response_body.bytesize).to eq(described_class::BODY_LIMIT)
    expect(execution.body_truncated).to be(true)
  end

  it "records transport errors" do
    stub_request(:get, api_request.url).to_raise(Errno::ECONNREFUSED)

    expect(execution).to have_attributes(error_kind: "refused", status: nil)
  end

  it "records invalid requests without sending them", :aggregate_failures do
    api_request.update!(url: "{{missing}}/x")

    expect(result).to be_success
    expect(execution).to have_attributes(error_kind: "invalid_request", url: "{{missing}}/x", unresolved_variables: ["missing"], status: nil)
  end

  it "keeps only the most recent executions" do
    create_list(:request_execution, RequestExecution::KEEP_PER_REQUEST + 2, api_request:)
    stub_request(:get, api_request.url).to_return(status: 200)

    result

    expect(api_request.request_executions.count).to eq(RequestExecution::KEEP_PER_REQUEST)
  end

  it "keeps all executions below the limit" do
    stub_request(:get, api_request.url).to_return(status: 200)

    expect { result }.to change(api_request.request_executions, :count).by(1)
  end

  describe "with pending edits" do
    let(:attributes) { { url: "https://api.example.com/edited" } }

    it "saves them before sending", :aggregate_failures do
      stub_request(:get, "https://api.example.com/edited").to_return(status: 200)

      expect(execution.url).to eq("https://api.example.com/edited")
      expect(api_request.reload.url).to eq("https://api.example.com/edited")
    end

    it "returns the failure when the edits are invalid" do
      invalid = described_class.call(api_request:, environment:, user:, attributes: { name: "" })

      expect(invalid).to be_failure
      expect(invalid.record).to eq(api_request)
    end
  end
end
