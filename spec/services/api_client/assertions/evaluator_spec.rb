require "rails_helper"

RSpec.describe ApiClient::Assertions::Evaluator do
  let(:body) { { token: "abc", count: 3, ok: true, none: nil, items: [{ id: 1 }, { id: 2 }], user: { name: "Ana" }, tags: %w[a b] }.to_json }
  let(:headers) { [["Content-Type", "application/json; charset=utf-8"], ["X-Request-Id", "r-1"]] }
  let(:response) { described_class::Response.new(status: 201, headers:, body:, duration_ms: 120, size_bytes: 300) }
  let(:resolver) { nil }
  let(:masker) { nil }

  def run(*rows)
    described_class.call(rows: rows, response:, resolver:, masker:)
  end

  def check(source, operator, expected: "", target: "")
    run({ "source" => source, "target" => target, "operator" => operator, "expected" => expected }).first
  end

  def status_of(*args, **options)
    check(*args, **options)["status"]
  end

  describe "status" do
    it "compares the code", :aggregate_failures do
      expect(status_of("status", "equals", expected: "201")).to eq("passed")
      expect(status_of("status", "equals", expected: "200")).to eq("failed")
      expect(status_of("status", "not_equals", expected: "200")).to eq("passed")
      expect(status_of("status", "lt", expected: "300")).to eq("passed")
      expect(status_of("status", "gt", expected: "300")).to eq("failed")
    end

    it "checks a range", :aggregate_failures do
      expect(status_of("status", "in_range", expected: "200-299")).to eq("passed")
      expect(status_of("status", "in_range", expected: "400 - 499")).to eq("failed")
      expect(check("status", "in_range", expected: "2xx")).to include("status" => "failed", "error" => "invalid_expected")
    end

    it "fails on a value that is not a number" do
      expect(check("status", "equals", expected: "ok")).to include("status" => "failed", "error" => "invalid_expected")
    end
  end

  describe "header" do
    it "looks the header up without regard to case", :aggregate_failures do
      expect(status_of("header", "exists", target: "x-request-id")).to eq("passed")
      expect(status_of("header", "not_exists", target: "x-missing")).to eq("passed")
      expect(status_of("header", "equals", target: "X-Request-Id", expected: "r-1")).to eq("passed")
      expect(status_of("header", "contains", target: "content-type", expected: "json")).to eq("passed")
      expect(status_of("header", "matches", target: "content-type", expected: "\\Aapplication/")).to eq("passed")
    end

    it "fails operators that need the header when it is missing", :aggregate_failures do
      expect(status_of("header", "equals", target: "x-missing", expected: "a")).to eq("failed")
      expect(status_of("header", "contains", target: "x-missing", expected: "a")).to eq("failed")
      expect(status_of("header", "matches", target: "x-missing", expected: "a")).to eq("failed")
    end

    it "reads a hash of headers too" do
      hash = described_class::Response.new(status: 200, headers: { "X-A" => "1" }, body: "")

      expect(described_class.call(rows: [{ "source" => "header", "target" => "x-a", "operator" => "equals", "expected" => "1" }], response: hash).first["status"]).to eq("passed")
    end
  end

  describe "json" do
    it "checks existence", :aggregate_failures do
      expect(status_of("json", "exists", target: "$.token")).to eq("passed")
      expect(status_of("json", "exists", target: "$.none")).to eq("passed")
      expect(status_of("json", "exists", target: "$.nope")).to eq("failed")
      expect(status_of("json", "not_exists", target: "$.nope")).to eq("passed")
      expect(status_of("json", "not_exists", target: "$.token")).to eq("failed")
    end

    it "compares values as text", :aggregate_failures do
      expect(status_of("json", "equals", target: "$.token", expected: "abc")).to eq("passed")
      expect(status_of("json", "equals", target: "$.count", expected: "3")).to eq("passed")
      expect(status_of("json", "equals", target: "$.ok", expected: "true")).to eq("passed")
      expect(status_of("json", "equals", target: "$.none", expected: "null")).to eq("passed")
      expect(status_of("json", "not_equals", target: "$.token", expected: "abc")).to eq("failed")
    end

    it "checks containment in strings, arrays and objects", :aggregate_failures do
      expect(status_of("json", "contains", target: "$.token", expected: "bc")).to eq("passed")
      expect(status_of("json", "contains", target: "$.tags", expected: "b")).to eq("passed")
      expect(status_of("json", "contains", target: "$.user", expected: "name")).to eq("passed")
      expect(status_of("json", "contains", target: "$.tags", expected: "z")).to eq("failed")
    end

    it "matches a pattern and compares numbers", :aggregate_failures do
      expect(status_of("json", "matches", target: "$.token", expected: "^a.c$")).to eq("passed")
      expect(status_of("json", "lt", target: "$.count", expected: "5")).to eq("passed")
      expect(status_of("json", "gt", target: "$.count", expected: "5")).to eq("failed")
      expect(check("json", "lt", target: "$.token", expected: "5")).to include("status" => "failed", "error" => "not_a_number")
      expect(check("json", "lt", target: "$.ok", expected: "5")).to include("error" => "not_a_number")
    end

    it "checks types and lengths", :aggregate_failures do
      expect(status_of("json", "type", target: "$.token", expected: "string")).to eq("passed")
      expect(status_of("json", "type", target: "$.count", expected: "number")).to eq("passed")
      expect(status_of("json", "type", target: "$.ok", expected: "boolean")).to eq("passed")
      expect(status_of("json", "type", target: "$.tags", expected: "array")).to eq("passed")
      expect(status_of("json", "type", target: "$.user", expected: "object")).to eq("passed")
      expect(status_of("json", "type", target: "$.none", expected: "null")).to eq("passed")
      expect(status_of("json", "length", target: "$.tags", expected: "2")).to eq("passed")
      expect(status_of("json", "length", target: "$.token", expected: "3")).to eq("passed")
      expect(status_of("json", "length", target: "$.user", expected: "1")).to eq("passed")
      expect(check("json", "length", target: "$.count", expected: "1")).to include("error" => "no_length")
    end

    it "uses all the matches of a wildcard", :aggregate_failures do
      expect(status_of("json", "length", target: "$.items[*].id", expected: "2")).to eq("passed")
      expect(status_of("json", "equals", target: "$.items[*].id", expected: "[1,2]")).to eq("passed")
    end

    it "fails with a reason when nothing is found, the path is bad or the body is not JSON", :aggregate_failures do
      expect(check("json", "equals", target: "$.nope", expected: "a")).to include("status" => "failed", "error" => "not_found")
      expect(check("json", "exists", target: "$..[")).to include("status" => "failed", "error" => "invalid_path")

      response.body = "<html>"
      expect(check("json", "exists", target: "$.a")).to include("status" => "failed", "error" => "invalid_json")
    end

    it "reports invalid JSON on every row, not only the first", :aggregate_failures do
      response.body = "nope"
      outcomes = run({ "source" => "json", "target" => "$.a", "operator" => "exists" }, { "source" => "json", "target" => "$.b", "operator" => "exists" })

      expect(outcomes.pluck("error")).to eq(%w[invalid_json invalid_json])
    end
  end

  describe "body" do
    it "checks the text", :aggregate_failures do
      expect(status_of("body", "contains", expected: "abc")).to eq("passed")
      expect(status_of("body", "not_contains", expected: "zzz")).to eq("passed")
      expect(status_of("body", "matches", expected: "token\":\"a")).to eq("passed")
      expect(status_of("body", "is_empty")).to eq("failed")
    end

    it "handles an empty or non-UTF-8 body", :aggregate_failures do
      response.body = nil
      expect(status_of("body", "is_empty")).to eq("passed")

      response.body = "ab\xFFcd".b
      expect(status_of("body", "contains", expected: "abcd")).to eq("passed")
    end

    it "reports a bad or slow pattern", :aggregate_failures do
      expect(check("body", "matches", expected: "(")).to include("error" => "invalid_pattern")

      allow(Regexp).to receive(:new).and_raise(Regexp::TimeoutError)
      expect(check("body", "matches", expected: "a+")).to include("error" => "pattern_timeout")
    end
  end

  describe "time and size" do
    it "compares against the response", :aggregate_failures do
      expect(status_of("time", "lt", expected: "200")).to eq("passed")
      expect(status_of("time", "lt", expected: "100")).to eq("failed")
      expect(status_of("size", "lt", expected: "1000")).to eq("passed")
      expect(check("time", "lt", expected: "100")["actual"]).to eq("120")
    end
  end

  describe "rows" do
    it "skips disabled rows and keeps the row as typed", :aggregate_failures do
      outcomes = run({ "source" => "status", "operator" => "equals", "expected" => "201", "enabled" => false }, { "source" => "status", "operator" => "equals", "expected" => "201", "target" => nil })

      expect(outcomes.size).to eq(1)
      expect(outcomes.first).to include("kind" => "assertion", "source" => "status", "operator" => "equals", "expected" => "201", "target" => "", "error" => nil)
    end

    it "fails a row the catalog does not know" do
      expect(run({ "source" => "status", "operator" => "bogus" }).first).to include("status" => "failed", "error" => "unsupported")
    end

    it "resolves variables in the expected value but stores it as typed", :aggregate_failures do
      resolver = ApiClient::VariableResolver.new({ "code" => "201" })
      outcome = described_class.call(rows: [{ "source" => "status", "operator" => "equals", "expected" => "{{code}}" }], response:, resolver:).first

      expect(outcome).to include("status" => "passed", "expected" => "{{code}}")
    end

    it "masks and cuts what it got", :aggregate_failures do
      masker = ApiClient::Masker.new(["abc"])
      outcome = described_class.call(rows: [{ "source" => "json", "target" => "$.token", "operator" => "equals", "expected" => "x" }], response:, masker:).first

      expect(outcome["actual"]).to eq(ApiClient::Masker::MASK)

      long = described_class::Response.new(status: 200, headers: [], body: { a: "x" * 500 }.to_json)
      cut = described_class.call(rows: [{ "source" => "json", "target" => "$.a", "operator" => "equals", "expected" => "y" }], response: long).first
      expect(cut["actual"].length).to eq(described_class::MAX_ACTUAL)
    end
  end
end
