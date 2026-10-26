require "rails_helper"

RSpec.describe ApiClient::Imports::Bruno do
  subject(:tree) { described_class.call(data: JSON.parse(file_fixture("imports/bruno_collection.json").read)).record }

  let(:collection) { tree[:collections].first }
  let(:requests) { collection[:requests].index_by { |request| request[:name] } }
  let(:folder) { collection[:folders].first }

  it "builds folders and requests ordered by seq", :aggregate_failures do
    expect(collection[:name]).to eq("Bruno Demo")
    expect(collection[:requests].first[:name]).to eq("Json")
    expect(collection[:folders].map { |item| item[:name] }).to eq(%w[Users Plain])
    expect(folder).to include(auth_type: "basic", auth_config: { "username" => "u", "password" => "p" })
  end

  it "pushes the collection auth to folders without one and top-level requests", :aggregate_failures do
    expect(collection[:folders].last).to include(auth_type: "bearer", auth_config: { "token" => "{{token}}", "prefix" => "Bearer" })
    expect(requests["NoBody"]).to include(auth_type: "bearer")
    expect(requests["Bare"]).to include(auth_type: "bearer", http_method: "GET", url: "")
  end

  it "maps query params, headers and inheritance inside a folder", :aggregate_failures do
    list = folder[:requests].first
    expect(list).to include(url: "{{host}}/users?limit=5", auth_type: "inherit")
    expect(list[:query_params].map { |row| row["key"] }).to eq(["limit"])
    expect(list[:headers].map { |row| [row["key"], row["enabled"]] }).to eq([["X", true], ["Off", false]])
  end

  it "maps body modes", :aggregate_failures do
    expect(requests["Json"]).to include(body_type: "json", body: "{\"a\":1}", auth_type: "none")
    expect(requests["Form"]).to include(body_type: "form_urlencoded")
    expect(requests["Multi"][:body_form].map { |row| [row["key"], row["type"], row["value"]] }).to eq([["f", "file", "a.png"], ["t", "text", "v"]])
    expect(requests["Graph"]).to include(body_type: "graphql", body: "{ a }", graphql_variables: "{}")
    expect(requests["Xml"]).to include(body_type: "xml", body: "<a/>")
    expect(requests["Text"]).to include(body_type: "text", body: "hi")
    expect(requests["File"]).to include(body_type: "none")
    expect(requests["NoBody"]).to include(body_type: "none")
  end

  it "maps authentication", :aggregate_failures do
    expect(requests["Form"]).to include(auth_type: "api_key", auth_config: { "key" => "K", "value" => "V", "add_to" => "query" })
    expect(requests["Multi"]).to include(auth_type: "digest")
    expect(requests["Graph"]).to include(auth_type: "aws_sigv4")
    expect(requests["Xml"]).to include(auth_type: "oauth2")
    expect(requests["File"]).to include(auth_type: "inherit")
    expect(requests["Text"]).to include(auth_type: "inherit")
  end

  it "imports environments with secrets and enabled flags", :aggregate_failures do
    expect(tree[:environments]).to eq([{ name: "Local", variables: [
      { key: "host", value: "http://localhost", secret: false, enabled: true },
      { key: "key", value: "k", secret: true, enabled: false }
    ] }])
  end

  it "warns about scripts, file bodies, unknown items and unsupported auth", :aggregate_failures do
    expect(tree[:warnings]).to include(
      I18n.t("workbench.imports.warnings.scripts", name: "List"), I18n.t("workbench.imports.warnings.scripts", name: "Text"),
      I18n.t("workbench.imports.warnings.file_body", name: "Multi"), I18n.t("workbench.imports.warnings.file_body", name: "File"),
      I18n.t("workbench.imports.warnings.unknown_item", type: "websocket-request"), I18n.t("workbench.imports.warnings.auth_unsupported", type: "wsse"),
      I18n.t("workbench.imports.warnings.auth_unsupported", type: "implicit")
    )
  end

  it "handles API keys in the header and a collection without auth or environments", :aggregate_failures do
    data = { "name" => "N", "items" => [{ "type" => "http-request", "name" => "r", "request" => { "url" => "http://x", "auth" => { "mode" => "apikey", "apikey" => { "key" => "K", "value" => "V" } } } }] }
    result = described_class.call(data:).record
    expect(result[:collections].first[:requests].first[:auth_config]).to include("add_to" => "header")
    expect(result[:environments]).to eq([])
  end
end
