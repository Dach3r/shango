require "rails_helper"

RSpec.describe ApiClient::Assertions::Extractor do
  let(:body) { { token: "abc", user: { id: 7 }, items: [1, 2] }.to_json }
  let(:response) { ApiClient::Assertions::Evaluator::Response.new(status: 201, headers: [%w[X-Id h-1]], body:) }

  def extract(*rows)
    described_class.call(rows:, response:)
  end

  def row(source, variable, target: "", **extra)
    { "source" => source, "target" => target, "variable" => variable }.merge(extra)
  end

  it "reads json, header, status and body", :aggregate_failures do
    result = extract(row("json", "token", target: "$.token"), row("json", "uid", target: "$.user.id"), row("header", "hid", target: "x-id"), row("status", "code"), row("body", "raw"))

    expect(result.record).to eq("token" => "abc", "uid" => "7", "hid" => "h-1", "code" => "201", "raw" => body)
    expect(result.data[:outcomes].pluck("status")).to all(eq("passed"))
  end

  it "joins several matches as JSON" do
    expect(extract(row("json", "items", target: "$.items[*]")).record).to eq("items" => "[1,2]")
  end

  it "warns instead of failing when the value is missing", :aggregate_failures do
    result = extract(row("json", "x", target: "$.nope"), row("header", "y", target: "x-none"), row("body", "z"))
    response.body = ""

    expect(result.record).to eq({ "z" => body })
    expect(result.data[:outcomes].first).to include("kind" => "extractor", "status" => "warning", "error" => "not_found", "variable" => "x")
  end

  it "warns on invalid JSON, a bad path or an empty body", :aggregate_failures do
    response.body = "<html>"
    expect(extract(row("json", "a", target: "$.a")).data[:outcomes].first["status"]).to eq("warning")

    response.body = body
    expect(extract(row("json", "a", target: "$..[")).data[:outcomes].first["status"]).to eq("warning")

    response.body = nil
    expect(extract(row("body", "a")).data[:outcomes].first["status"]).to eq("warning")
  end

  it "reports which variables are secret and skips disabled and unknown rows", :aggregate_failures do
    result = extract(row("json", "token", target: "$.token", "secret" => true), row("status", "code", "enabled" => false), row("nope", "a"), row("status", "1bad"))

    expect(result.record).to eq("token" => "abc")
    expect(result.data[:secrets]).to eq(["token"])
    expect(result.data[:outcomes].pluck("status")).to eq(%w[passed warning warning])
  end

  it "cuts a value that is too large" do
    stub_const("#{described_class}::MAX_VALUE", 5)

    expect(extract(row("json", "token", target: "$.token")).record["token"]).to eq("abc")
    expect(extract(row("body", "raw")).record["raw"].bytesize).to eq(5)
  end
end
