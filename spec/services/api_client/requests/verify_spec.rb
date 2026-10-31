require "rails_helper"

RSpec.describe ApiClient::Requests::Verify do
  let(:project) { create(:project) }
  let(:owner) { create(:user) }
  let(:environment) { create(:environment, project:) }
  let(:api_request) { create(:api_request, collection: create(:collection, project:)) }
  let(:masker) { ApiClient::Masker.new([]) }
  let(:error_kind) { nil }
  let(:reply) do
    ApiClient::Executor::Reply.new(status: 200, headers: [%w[X-Id 1]], body: { token: "abc" }.to_json, duration_ms: 10, size_bytes: 15, error_kind:)
  end
  let(:result) { described_class.call(api_request:, reply:, environment:, user: owner, masker:) }

  before { create(:membership, :owner, user: owner, project:) }

  it "has nothing to say when the request has no assertions or extractors" do
    expect(result.record).to eq([])
  end

  it "evaluates assertions, then extractors, and saves the extracted variables", :aggregate_failures do
    api_request.update!(assertions: [{ source: "status", operator: "equals", expected: "200" }], extractors: [{ source: "json", target: "$.token", variable: "token" }])

    expect(result.record.pluck("kind", "status")).to eq([%w[assertion passed], %w[extractor passed]])
    expect(environment.variables.find_by(key: "token").value).to eq("abc")
  end

  it "resolves variables of the environment in the expected value" do
    create(:variable, environment:, key: "code", value: "200")
    api_request.update!(assertions: [{ source: "status", operator: "equals", expected: "{{code}}" }])

    expect(result.record.first["status"]).to eq("passed")
  end

  it "warns when the values cannot be saved", :aggregate_failures do
    api_request.update!(extractors: [{ source: "json", target: "$.token", variable: "token" }])
    member = create(:user)
    create(:membership, user: member, project:)

    outcomes = described_class.call(api_request:, reply:, environment:, user: member, masker:).record

    expect(outcomes.last).to eq({ "kind" => "extractor", "status" => "warning", "error" => "not_permitted" })
    expect(environment.variables).to be_empty
  end

  it "warns when there is no environment to save to" do
    api_request.update!(extractors: [{ source: "json", target: "$.token", variable: "token" }])

    outcomes = described_class.call(api_request:, reply:, environment: nil, user: owner, masker:).record

    expect(outcomes.last).to include("status" => "warning", "error" => "no_environment")
  end

  it "does not save anything when no extractor found a value" do
    api_request.update!(extractors: [{ source: "json", target: "$.nope", variable: "token" }])

    expect(result.record.pluck("status")).to eq(["warning"])
  end

  context "when the request failed" do
    let(:error_kind) { "timeout" }

    it "checks nothing" do
      api_request.update!(assertions: [{ source: "status", operator: "equals", expected: "200" }])

      expect(result.record).to eq([])
    end
  end
end
