require "rails_helper"

RSpec.describe ApiClient::Exports::Postman do
  include_context "with exportable collection"

  subject(:data) { described_class.call(collection: export_collection, environments:, credentials:).data }

  let(:items) { data[:collection][:item] }
  let(:users) { items.find { |item| item[:name] == "Users" } }

  def find(name, list = items)
    list.flat_map { |item| item[:item] ? [item, *flatten(item[:item])] : [item] }.find { |item| item[:name] == name }
  end

  def flatten(list)
    list.flat_map { |item| item[:item] ? [item, *flatten(item[:item])] : [item] }
  end

  it "describes the collection, its auth and the nested folders", :aggregate_failures do
    expect(data[:collection][:info]).to include(name: "Pet Store", description: "All pets", schema: described_class::SCHEMA)
    expect(data[:collection][:auth]).to eq(type: "basic", "basic" => [{ key: "username", value: "root", type: "string" }, { key: "password", value: "", type: "string" }])
    expect(users[:auth]).to include(type: "bearer")
    expect(users[:item].first).to include(name: "Admin")
    expect(users[:item].first).not_to have_key(:auth)
    expect(items.map { |item| item[:name] }).to eq(%w[Users Open List] + ["List again"])
  end

  it "maps URL, rows, description and raw bodies", :aggregate_failures do
    request = find("List")[:request]

    expect(request).to include(method: "GET", description: "Lists")
    expect(request[:url]).to eq(raw: "{{baseUrl}}/users/{{id}}?limit=10", query: [{ key: "limit", value: "10", disabled: false }, { key: "page", value: "2", disabled: true, description: "Page" }])
    expect(request[:header].map { |row| row[:disabled] }).to eq([false, false, true])
    expect(request[:body]).to eq(mode: "raw", raw: '{"a":1}', options: { raw: { language: "json" } })
    expect(find("Create")[:request][:body]).to include(mode: "raw", options: { raw: { language: "xml" } })
  end

  it "maps form, multipart and GraphQL bodies, and leaves binary out", :aggregate_failures do
    expect(find("Form")[:request][:body]).to eq(mode: "urlencoded", urlencoded: [{ key: "a", value: "{{$guid}}", disabled: false }])
    expect(find("Upload")[:request][:body][:formdata]).to eq([{ key: "title", disabled: false, type: "text", value: "x" }, { key: "file", disabled: true, type: "file", src: "a.png" }])
    expect(find("Query")[:request][:body]).to eq(mode: "graphql", graphql: { query: "{ pets }", variables: '{"a":1}' })
    expect(find("Binary")[:request]).not_to have_key(:body)
  end

  it "maps every auth strategy without secrets", :aggregate_failures do
    auth = ->(name) { find(name)[:request][:auth] }

    expect(auth.call("Note")).to eq(type: "noauth")
    expect(auth.call("Create")).to include(type: "apikey", "apikey" => include({ key: "in", value: "query", type: "string" }, { key: "value", value: "", type: "string" }))
    expect(auth.call("Key")["apikey"]).to include({ key: "in", value: "header", type: "string" })
    expect(auth.call("Form")).to include(type: "digest")
    expect(auth.call("Upload")["awsv4"]).to include({ key: "accessKey", value: "AK", type: "string" }, { key: "secretKey", value: "", type: "string" })
    expect(auth.call("Query")["oauth2"]).to include({ key: "grant_type", value: "client_credentials", type: "string" }, { key: "clientSecret", value: "", type: "string" })
    expect(auth.call("Query plain")["oauth2"]).not_to include(include(key: "grant_type"))
    expect(auth.call("Token")).to include(type: "bearer")
    expect(auth.call("Binary")).to be_nil
    expect(auth.call("List")).to be_nil
  end

  it "does not describe an unauthenticated collection" do
    export_collection.update!(auth_type: "none")

    expect(data[:collection]).not_to have_key(:auth)
  end

  it "writes one environment per Postman environment with secrets masked", :aggregate_failures do
    document = data[:environments].first

    expect(document).to include(name: "Staging", _postman_variable_scope: "environment")
    expect(document[:values]).to eq([
      { key: "baseUrl", value: "https://stg.example.com/", type: "default", enabled: true },
      { key: "TOKEN", value: "", type: "secret", enabled: true },
      { key: "OFF", value: "x", type: "default", enabled: false }
    ])
  end

  it "is read back by the Postman importer", :aggregate_failures do
    tree = ApiClient::Imports::Postman.call(data: JSON.parse(data[:collection].to_json)).record

    expect(tree[:collections].first).to include(name: "Pet Store", description: "All pets")
    expect(tree[:collections].first[:folders].first).to include(name: "Users", auth_type: "bearer")
    expect(tree[:collections].first[:requests].first).to include(name: "List", url: "{{baseUrl}}/users/{{id}}?limit=10")
  end
end
