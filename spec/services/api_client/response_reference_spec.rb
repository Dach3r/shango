require "rails_helper"

RSpec.describe ApiClient::ResponseReference do
  let(:project) { create(:project) }
  let(:collection) { create(:collection, project:) }
  let(:user) { create(:user) }
  let(:current) { create(:api_request, collection:) }
  let(:source) { create(:api_request, collection:) }
  let(:body) { '{"id":638,"name":"Ana","ok":true,"tags":["a","b"],"items":[{"id":1},{"id":2}],"meta":{"k":1}}' }
  let(:response_headers) { [["Content-Type", "application/json"], ["X-Trace", "abc"]] }
  let(:reference) { "response.body.#{source.id}.$.id" }

  before do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    create(:request_execution, api_request: source, user:, url: "https://api.example.com/created", response_body: body, response_headers:)
  end

  def call(name = reference, api_request: current)
    described_class.call(api_request:, user:, name:)
  end

  describe ".parse" do
    it "splits attribute, request and filter", :aggregate_failures do
      expect(described_class.parse(reference)).to have_attributes(attribute: "body", request_id: source.id, filter: "$.id")
      expect(described_class.parse("response.raw.#{source.id}")).to have_attributes(attribute: "raw", filter: nil)
    end

    it "rejects malformed references", :aggregate_failures do
      expect(described_class.parse("response.body.#{source.id}")).to be_nil
      expect(described_class.parse("response.header.#{source.id}")).to be_nil
      expect(described_class.parse("response.nope.#{source.id}")).to be_nil
      expect(described_class.parse("response.body.name.$.id")).to be_nil
    end
  end

  describe ".reference?" do
    it "tells response names apart", :aggregate_failures do
      expect(described_class.reference?("response.url.x")).to be(true)
      expect(described_class.reference?("host")).to be(false)
    end
  end

  describe "#perform" do
    it "reads a JSONPath scalar", :aggregate_failures do
      expect(call).to be_success
      expect(call.record).to eq("638")
      expect(call.data[:request]).to eq(source)
    end

    it "reads strings, booleans and structures", :aggregate_failures do
      expect(call("response.body.#{source.id}.$.name").record).to eq("Ana")
      expect(call("response.body.#{source.id}.$.ok").record).to eq("true")
      expect(call("response.body.#{source.id}.$.meta").record).to eq('{"k":1}')
      expect(call("response.body.#{source.id}.$.items[*].id").record).to eq("[1,2]")
    end

    it "reads the raw body, a header (case-insensitive) and the url", :aggregate_failures do
      expect(call("response.raw.#{source.id}").record).to eq(body)
      expect(call("response.header.#{source.id}.x-trace").record).to eq("abc")
      expect(call("response.url.#{source.id}").record).to eq("https://api.example.com/created")
    end

    it "fails when nothing matches", :aggregate_failures do
      expect(call("response.body.#{source.id}.$.missing")).to have_attributes(failure?: true, error: :no_match)
      expect(call("response.header.#{source.id}.X-Nope")).to have_attributes(error: :no_match)
    end

    it "fails on a body that is not JSON or is missing", :aggregate_failures do
      source.request_executions.destroy_all
      create(:request_execution, api_request: source, user:, response_body: "<html>")
      expect(call).to have_attributes(error: :no_match)

      source.request_executions.destroy_all
      create(:request_execution, api_request: source, user:, response_body: nil)
      expect(call).to have_attributes(error: :no_match)
    end

    it "reads falsy and null JSON values", :aggregate_failures do
      source.request_executions.destroy_all
      create(:request_execution, api_request: source, user:, response_body: '{"off":false,"zero":0,"empty":"","nothing":null}')

      expect(call("response.body.#{source.id}.$.off").record).to eq("false")
      expect(call("response.body.#{source.id}.$.zero").record).to eq("0")
      expect(call("response.body.#{source.id}.$.empty").record).to eq("")
      expect(call("response.body.#{source.id}.$.nothing")).to have_attributes(error: :no_match)
    end

    it "fails with no match for an invalid JSONPath instead of raising", :aggregate_failures do
      expect(call("response.body.#{source.id}.$[?(")).to have_attributes(failure?: true, error: :no_match)
      expect(call("response.body.#{source.id}.$..[")).to have_attributes(failure?: true)
    end

    it "fails for a body that is a JSON scalar or null", :aggregate_failures do
      source.request_executions.destroy_all
      create(:request_execution, api_request: source, user:, response_body: "null")

      expect(call).to have_attributes(failure?: true, error: :no_match)
    end

    it "accepts upper case request ids" do
      expect(call("response.body.#{source.id.upcase}.$.id").record).to eq("638")
    end

    it "keeps newlines and unicode of the raw body", :aggregate_failures do
      source.request_executions.destroy_all
      create(:request_execution, api_request: source, user:, response_body: "línea 1\nlínea 2 🦤")

      expect(call("response.raw.#{source.id}").record).to eq("línea 1\nlínea 2 🦤")
    end

    it "does not reach requests of another project", :aggregate_failures do
      foreign = create(:api_request, collection: create(:collection))
      create(:request_execution, api_request: foreign, user:, response_body: '{"id":1}')

      expect(call("response.body.#{foreign.id}.$.id")).to have_attributes(failure?: true, error: :unknown_request)
    end

    it "fails on an invalid reference", :aggregate_failures do
      expect(call("response.body")).to have_attributes(failure?: true, error: :invalid)
    end

    it "fails when the request has no response for the user or it errored", :aggregate_failures do
      other = create(:api_request, collection:)
      expect(call("response.url.#{other.id}")).to have_attributes(error: :no_response)

      source.request_executions.destroy_all
      create(:request_execution, api_request: source, user:, error_kind: "timeout")
      expect(call).to have_attributes(error: :no_response)
    end

    it "ignores responses of other users" do
      source.request_executions.update_all(user_id: create(:user).id)

      expect(call).to have_attributes(error: :no_response)
    end

    it "only reaches requests of the same collection", :aggregate_failures do
      outsider = create(:api_request, collection: create(:collection, project:))
      create(:request_execution, api_request: outsider, user:)

      expect(call("response.url.#{outsider.id}")).to have_attributes(error: :unknown_request)
      expect(call("response.url.#{source.id}", api_request: create(:api_request, collection: create(:collection, project:)))).to have_attributes(error: :unknown_request)
    end

    it "never resolves for a draft", :aggregate_failures do
      draft = ApiClient::Drafts::Build.call(draft: create(:request_draft, user:, project:))

      expect(call(api_request: draft)).to have_attributes(error: :unknown_request)
    end
  end
end
