require "rails_helper"

RSpec.describe ApiClient::Exports::AssertionScript do
  let(:body) { { token: "abc", count: 3, ok: true, none: nil, items: [{ id: 1 }, { id: 2 }], user: { "first name" => "Ana" }, tags: %w[a b] }.to_json }
  let(:headers) { [["Content-Type", "application/json; charset=utf-8"], ["X-Request-Id", "r-1"]] }
  let(:response) { { status: 201, status_text: "Created", headers:, body:, duration_ms: 120 } }
  let(:request) { { url: "https://a.test/x", http_method: "GET", headers: [], body: "" } }

  def generate(assertions: [], extractors: [])
    described_class.call(assertions:, extractors:).record
  end

  def row(source, operator, target: "", expected: "")
    { "source" => source, "target" => target, "operator" => operator, "expected" => expected, "enabled" => true }
  end

  # What the script would say when run by Shango's own pm: one test per exported assertion, pass or fail.
  def script_results(rows)
    outcome = ApiClient::Scripting::Sandbox.call(source: generate(assertions: rows), phase: :post, environment: {}, variables: {}, request:, response:).record
    raise outcome.error if outcome.error

    outcome.tests.to_h { |test| [test["name"], test["passed"]] }
  end

  def declarative_results(rows)
    evaluator = ApiClient::Assertions::Evaluator::Response.new(status: 201, headers:, body:, duration_ms: 120, size_bytes: body.bytesize)
    ApiClient::Assertions::Evaluator.call(rows:, response: evaluator).to_h { |outcome| [ApiClient::Assertions::Describe.title(outcome), outcome["status"] == "passed"] }
  end

  it "is empty without rows" do
    expect(generate).to eq("")
  end

  it "says what it generated from" do
    expect(generate(assertions: [row("status", "equals", expected: "201")])).to start_with(described_class::HEADER)
  end

  it "skips disabled rows" do
    expect(generate(assertions: [row("status", "equals", expected: "201").merge("enabled" => false)], extractors: [{ "source" => "status", "variable" => "c", "enabled" => false }])).to eq("")
  end

  describe "the exported assertions agree with the ones Shango evaluates" do
    let(:rows) do
      [
        row("status", "equals", expected: "201"), row("status", "equals", expected: "200"), row("status", "not_equals", expected: "200"), row("status", "lt", expected: "300"),
        row("status", "gt", expected: "300"), row("status", "in_range", expected: "200-299"), row("status", "in_range", expected: "400-499"),
        row("header", "exists", target: "x-request-id"), row("header", "exists", target: "x-nope"), row("header", "not_exists", target: "x-nope"),
        row("header", "equals", target: "X-Request-Id", expected: "r-1"), row("header", "contains", target: "content-type", expected: "json"),
        row("header", "matches", target: "content-type", expected: "^application/"),
        row("json", "exists", target: "$.token"), row("json", "exists", target: "$.nope"), row("json", "not_exists", target: "$.nope"),
        row("json", "equals", target: "$.token", expected: "abc"), row("json", "equals", target: "$.count", expected: "3"), row("json", "not_equals", target: "$.token", expected: "abc"),
        row("json", "contains", target: "$.token", expected: "bc"), row("json", "matches", target: "$.token", expected: "^a.c$"),
        row("json", "lt", target: "$.count", expected: "5"), row("json", "gt", target: "$.count", expected: "5"),
        row("json", "type", target: "$.tags", expected: "array"), row("json", "type", target: "$.token", expected: "number"),
        row("json", "length", target: "$.tags", expected: "2"), row("json", "equals", target: "$.items[1].id", expected: "2"), row("json", "equals", target: "$.user['first name']", expected: "Ana"),
        row("body", "contains", expected: "abc"), row("body", "not_contains", expected: "zzz"), row("body", "matches", expected: "token"), row("body", "is_empty"),
        row("time", "lt", expected: "200"), row("time", "lt", expected: "100")
      ]
    end

    it "pass and fail the same rows", :aggregate_failures do
      expected = declarative_results(rows)
      actual = script_results(rows)

      expect(actual.keys).to match_array(expected.keys)
      expected.each { |title, passed| expect(actual.fetch(title)).to eq(passed), "#{title}: expected #{passed}, script said #{actual[title]}" }
    end
  end

  it "leaves out what has no direct translation, saying so", :aggregate_failures do
    script = generate(
      assertions: [row("json", "exists", target: "$.items[*].id"), row("status", "equals", expected: "ok"), row("time", "lt", expected: "fast"), row("size", "lt", expected: "x"), row("json", "lt", target: "$.a", expected: "x"), row("json", "length", target: "$.a", expected: "x"), row("status", "in_range", expected: "2xx"), row("status", "in_range", expected: "200")],
      extractors: [{ "source" => "json", "target" => "$..id", "variable" => "ids" }]
    )

    expect(script.scan("// Not exported").size).to eq(9)
    expect(script).not_to include("pm.test(")
  end

  it "exports the size check" do
    expect(generate(assertions: [row("size", "lt", expected: "1000")])).to include("pm.response.responseSize")
  end

  it "resolves variables in expected values when the script runs" do
    script = generate(assertions: [row("body", "contains", expected: "{{token}}"), row("header", "equals", target: "x", expected: "{{id}}")])

    expect(script).to include('pm.variables.replaceIn("{{token}}")', 'pm.variables.replaceIn("{{id}}")')
  end

  it "quotes hostile values so they stay data", :aggregate_failures do
    hostile = '");pm.environment.set("pwned", "1");//'
    rows = [row("body", "contains", expected: hostile)]
    outcome = ApiClient::Scripting::Sandbox.call(source: generate(assertions: rows), phase: :post, environment: {}, variables: {}, request:, response:).record

    expect(outcome.error).to be_nil
    expect(outcome.env_writes).to be_empty
    expect(outcome.tests.pluck("passed")).to eq([false])
  end

  describe "extractors" do
    it "set the variables in the Postman environment when the script runs", :aggregate_failures do
      script = generate(extractors: [
        { "source" => "json", "target" => "$.token", "variable" => "token" }, { "source" => "json", "target" => "$.items[0].id", "variable" => "first" }, { "source" => "json", "target" => "$.tags", "variable" => "tags" },
        { "source" => "json", "target" => "$.nope", "variable" => "missing" }, { "source" => "header", "target" => "x-request-id", "variable" => "rid" },
        { "source" => "status", "variable" => "code" }, { "source" => "body", "variable" => "raw" }
      ])
      outcome = ApiClient::Scripting::Sandbox.call(source: script, phase: :post, environment: {}, variables: {}, request:, response:).record

      expect(outcome.error).to be_nil
      expect(outcome.env_writes).to eq("token" => "abc", "first" => "1", "tags" => '["a","b"]', "rid" => "r-1", "code" => "201", "raw" => body)
    end
  end
end
