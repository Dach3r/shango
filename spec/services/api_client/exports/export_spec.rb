require "rails_helper"

RSpec.describe ApiClient::Exports::Export do
  include_context "with exportable collection"

  def export(format, **options)
    described_class.call(collection: export_collection, format:, **options)
  end

  it "names the JSON file after the collection and format", :aggregate_failures do
    result = export("insomnia")

    expect(result.data).to include(filename: "pet-store.insomnia.json", content_type: "application/json")
    expect(JSON.parse(result.data[:content])["_type"]).to eq("export")
  end

  it "exports a Postman collection alone as JSON", :aggregate_failures do
    result = export("postman")

    expect(result.data[:filename]).to eq("pet-store.postman_collection.json")
    expect(JSON.parse(result.data[:content]).dig("info", "name")).to eq("Pet Store")
  end

  it "zips the Postman collection with its environments", :aggregate_failures do
    result = export("postman", include_environments: true)

    expect(result.data).to include(filename: "pet-store.zip", content_type: "application/zip")
    expect(result.data[:content]).to include("pet-store.postman_collection.json").and include("1-staging.postman_environment.json")
  end

  it "falls back to a generic name when the collection name has nothing usable", :aggregate_failures do
    export_collection.update!(name: "???")
    export_environment.update!(name: "!!!")

    expect(export("shango").data[:filename]).to eq("collection.shango.json")
    expect(export("postman", include_environments: true).data[:content]).to include("1-environment.postman_environment.json")
  end

  it "includes environments only when asked", :aggregate_failures do
    expect(JSON.parse(export("shango").data[:content])).not_to have_key("environments")
    expect(JSON.parse(export("shango", include_environments: true).data[:content])["environments"].first["name"]).to eq("Staging")
  end

  it "leaves secrets out unless credentials are included", :aggregate_failures do
    expect(export("shango", include_environments: true).data[:content]).not_to include("hunter2", "s3cret")
    expect(export("shango", include_environments: true, include_credentials: true).data[:content]).to include("hunter2", "s3cret")
  end

  it "uses the environments of OpenAPI only for the server", :aggregate_failures do
    content = export("openapi").data[:content]

    expect(content).to include("https://stg.example.com")
    expect(content).not_to include("s3cret")
  end

  it "rejects an unknown format", :aggregate_failures do
    result = export("csv")

    expect(result).to be_failure
    expect(result.error).to eq(I18n.t("workbench.exports.errors.unknown_format"))
  end

  it "round-trips through the Shango importer", :aggregate_failures do
    content = export("shango", include_environments: true, include_credentials: true).data[:content]
    target = create(:project)
    result = ApiClient::Imports::Import.call(project: target, creator: nil, content:)
    copy = target.collections.first

    expect(result.data).to include(collections: 1, folders: 3, requests: 11, environments: 1)
    expect(copy.auth_config).to eq("username" => "root", "password" => "hunter2")
    expect(copy.api_requests.find_by!(name: "List").settings).to include("follow_redirects" => false)
    expect(target.environments.first.variables.find_by!(key: "TOKEN")).to have_attributes(value: "s3cret", secret: true)
  end
end
