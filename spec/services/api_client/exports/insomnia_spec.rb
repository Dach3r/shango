require "rails_helper"

RSpec.describe ApiClient::Exports::Insomnia do
  include_context "with exportable collection"

  subject(:resources) { described_class.call(collection: export_collection, environments:, credentials: ApiClient::Exports::Credentials.new(include: true)).data[:document][:resources] }

  def resource(name)
    resources.find { |entry| entry[:name] == name }
  end

  it "exports a workspace with request groups and requests", :aggregate_failures do
    workspace = resources.first

    expect(workspace).to include(_type: "workspace", name: "Pet Store")
    expect(resource("Users")).to include(_type: "request_group", parentId: workspace[:_id], authentication: { type: "bearer", token: "tok-123", prefix: "Token" })
    expect(resource("Admin")).to include(parentId: resource("Users")[:_id], authentication: {})
    expect(resource("List")).to include(parentId: workspace[:_id], method: "GET", description: "Lists")
  end

  it "rewrites variables to Insomnia's syntax and keeps row flags", :aggregate_failures do
    request = resource("List")

    expect(request[:url]).to eq("{{ _.baseUrl }}/users/{{ _.id }}?limit=10")
    expect(request[:headers]).to eq([{ name: "X-Trace", value: "{{ $randomUUID }}", disabled: false }, { name: "Content-Type", value: "application/json", disabled: false }, { name: "X-Date", value: "{{ $timestamp }}", disabled: true }])
    expect(request[:parameters].last).to include(name: "page", disabled: true, description: "Page")
    expect(request[:settingFollowRedirects]).to eq("off")
    expect(resource("Note")[:settingFollowRedirects]).to eq("global")
  end

  it "maps every body type", :aggregate_failures do
    expect(resource("List")[:body]).to eq(mimeType: "application/json", text: '{"a":1}')
    expect(resource("Create")[:body]).to include(mimeType: "application/xml")
    expect(resource("Note")[:body]).to eq(mimeType: "text/plain", text: "hello {{ _.name }}")
    expect(resource("Form")[:body]).to eq(mimeType: "application/x-www-form-urlencoded", params: [{ name: "a", value: "{{ $randomUUID }}", disabled: false }])
    expect(resource("Upload")[:body][:params]).to eq([{ name: "title", disabled: false, value: "x" }, { name: "file", disabled: true, type: "file", fileName: "a.png" }])
    expect(JSON.parse(resource("Query")[:body][:text])).to eq("query" => "{ pets }", "variables" => '{"a":1}')
    expect(JSON.parse(resource("Query plain")[:body][:text])).to eq("query" => "{ x }")
    expect(resource("Binary")[:body]).to eq({})
  end

  it "maps every auth strategy", :aggregate_failures do
    expect(resource("Note")[:authentication]).to eq(type: "none")
    expect(resource("Create")[:authentication]).to include(type: "apikey", key: "k", value: "v1", addTo: "queryParams")
    expect(resource("Key")[:authentication]).to include(addTo: "header")
    expect(resource("Form")[:authentication]).to eq(type: "digest", username: "d", password: "dp")
    expect(resource("Upload")[:authentication]).to include(type: "iam", accessKeyId: "AK", secretAccessKey: "SK", region: "us-east-1")
    expect(resource("Query")[:authentication]).to include(type: "oauth2", grantType: "client_credentials", clientSecret: "csec")
    expect(resource("Query plain")[:authentication]).to eq({})
    expect(resource("Binary")[:authentication]).to eq({})
    expect(resource("Token")[:authentication]).to eq(type: "bearer", token: "b-1", prefix: "Bearer")
  end

  it "exports environments as sub-environments of a base one, without disabled variables", :aggregate_failures do
    base = resources.find { |entry| entry[:_type] == "environment" && entry[:name] == "Base Environment" }
    staging = resource("Staging")

    expect(staging[:parentId]).to eq(base[:_id])
    expect(staging[:data]).to eq("baseUrl" => "https://stg.example.com/", "TOKEN" => "s3cret")
  end

  it "has no environments when none are given" do
    document = described_class.call(collection: export_collection, environments: [], credentials:).data[:document]

    expect(document[:resources].pluck(:_type)).not_to include("environment")
  end

  it "is read back by the Insomnia importer", :aggregate_failures do
    document = described_class.call(collection: export_collection, environments:, credentials: ApiClient::Exports::Credentials.new(include: true)).data[:document]
    tree = ApiClient::Imports::Insomnia.call(data: JSON.parse(document.to_json)).record

    expect(tree[:collections].first[:requests].first).to include(name: "List", url: "{{baseUrl}}/users/{{id}}?limit=10")
    expect(tree[:environments].first).to include(name: "Staging")
  end
end
