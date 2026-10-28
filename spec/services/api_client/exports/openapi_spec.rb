require "rails_helper"

RSpec.describe ApiClient::Exports::Openapi do
  include_context "with exportable collection"

  subject(:document) { described_class.call(collection: export_collection, environments:, credentials:).data[:document] }

  let(:paths) { document[:paths] }

  it "describes the API and the servers found in the URLs", :aggregate_failures do
    expect(document).to include(openapi: "3.0.3", info: { title: "Pet Store", description: "All pets", version: "1.0.0" })
    expect(document[:servers]).to eq([{ url: "https://stg.example.com" }, { url: "https://api.example.com" }])
  end

  it "has one operation per method and path, the first request winning", :aggregate_failures do
    operation = paths["/users/{id}"]["get"]

    expect(operation).to include(summary: "List", description: "Lists")
    expect(paths.keys).to include("/users", "/forms", "/upload", "/graphql")
    expect(paths["/graphql"].keys).to eq(%w[post delete])
    expect(paths["/users/{id}"].values.size).to eq(1)
  end

  it "documents path, query and header parameters, skipping the headers OpenAPI reserves", :aggregate_failures do
    parameters = paths["/users/{id}"]["get"][:parameters]

    expect(parameters.map { |parameter| [parameter[:in], parameter[:name]] }).to eq([%w[path id], %w[query limit], %w[query page], %w[header X-Trace], %w[header X-Date]])
    expect(parameters.find { |parameter| parameter[:name] == "page" }).to include(description: "Page", required: false)
  end

  it "names folders as tags" do
    expect(paths["/forms"]["post"][:tags]).to eq(["Users / Admin"])
    expect(paths["/users/{id}"]["get"]).not_to have_key(:tags)
  end

  it "builds request bodies from the examples", :aggregate_failures do
    body = ->(path, method, type) { paths.dig(path, method, :requestBody, :content, type) }

    expect(body.call("/users/{id}", "get", "application/json")).to include(example: { "a" => 1 })
    expect(body.call("/users", "post", "application/xml")).to include(example: "<a/>")
    expect(body.call("/users", "put", "text/plain")).to include(example: "hello {{name}}")
    expect(body.call("/forms", "post", "application/x-www-form-urlencoded")[:schema][:properties]).to eq("a" => { type: "string", example: "{{$guid}}" })
    expect(body.call("/upload", "post", "multipart/form-data")[:schema][:properties]).to eq("title" => { type: "string", example: "x" }, "file" => { type: "string", format: "binary" })
    expect(body.call("/graphql", "post", "application/json")[:example]).to eq(query: "{ pets }", variables: { "a" => 1 })
    expect(paths.dig("/bin", "patch")).not_to have_key(:requestBody)
  end

  it "keeps invalid JSON examples as text" do
    export_collection.api_requests.find_by!(name: "List").update!(body: "not json")

    expect(paths["/users/{id}"]["get"][:requestBody][:content]["application/json"][:example]).to eq("not json")
  end

  it "keeps a blank JSON example out" do
    export_collection.api_requests.find_by!(name: "List").update!(body: "")

    expect(paths["/users/{id}"]["get"][:requestBody][:content]["application/json"]).not_to have_key(:example)
  end

  it "declares the security schemes, following inheritance", :aggregate_failures do
    schemes = document[:components][:securitySchemes]
    security = ->(path, method) { paths.dig(path, method, :security) }

    expect(schemes).to include("bearerAuth" => { type: "http", scheme: "bearer" }, "digestAuth" => { type: "http", scheme: "digest" }, "basicAuth" => { type: "http", scheme: "basic" })
    expect(schemes).to include("apiKey_k" => { type: "apiKey", name: "k", in: "query" }, "apiKey_X_Key" => { type: "apiKey", name: "X-Key", in: "header" })
    expect(security.call("/users/{id}", "get")).to eq([{ "basicAuth" => [] }])
    expect(security.call("/forms", "post")).to eq([{ "digestAuth" => [] }])
    expect(security.call("/users", "put")).to be_nil
    expect(security.call("/upload", "post")).to be_nil
    expect(security.call("/graphql", "post")).to eq([{ "bearerAuth" => [] }])
  end

  it "leaves the servers and schemes out when there are none" do
    export_collection.folders.destroy_all
    export_collection.api_requests.where.not(name: "List again").destroy_all
    export_collection.update!(auth_type: "none")
    export_project.environments.destroy_all

    expect(described_class.call(collection: export_collection, environments: [], credentials:).data[:document]).not_to include(:servers, :components)
  end

  it "does not read secret variables for the server" do
    export_environment.variables.find_by!(key: "baseUrl").update!(secret: true)

    expect(document[:servers]).to eq([{ url: "https://api.example.com" }])
  end

  it "is read back by the OpenAPI importer" do
    tree = ApiClient::Imports::Openapi.call(data: JSON.parse(document.to_json)).record

    expect(tree[:collections].first[:name]).to eq("Pet Store")
  end
end
