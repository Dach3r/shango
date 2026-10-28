require "rails_helper"

RSpec.describe ApiClient::Exports::Shango do
  include_context "with exportable collection"

  let(:document) { described_class.call(collection: export_collection, environments:, credentials: ApiClient::Exports::Credentials.new(include: true)).data[:document] }

  it "carries the whole collection", :aggregate_failures do
    expect(document[:shango]).to eq(version: 1)
    expect(document[:collection]).to include(name: "Pet Store", description: "All pets", auth_type: "basic", auth_config: { "username" => "root", "password" => "hunter2" })
    expect(document[:collection][:folders].pluck(:name)).to eq(%w[Users Open])
    expect(document[:collection][:folders].first[:folders].first[:requests].pluck(:name)).to eq(%w[Form Upload])
    expect(document[:collection][:requests].first).to include(name: "List", http_method: "GET", body_type: "json", settings: include("follow_redirects" => false))
  end

  it "omits the environments key when there are none" do
    expect(described_class.call(collection: export_collection, environments: [], credentials:).data[:document]).not_to have_key(:environments)
  end

  it "masks secrets by default", :aggregate_failures do
    document = described_class.call(collection: export_collection, environments:, credentials:).data[:document]

    expect(document[:collection][:auth_config]).to eq("username" => "root", "password" => "")
    expect(document[:environments].first[:variables].find { |variable| variable[:key] == "TOKEN" }).to include(value: "", secret: true)
  end
end
