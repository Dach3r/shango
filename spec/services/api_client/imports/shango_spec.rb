require "rails_helper"

RSpec.describe ApiClient::Imports::Shango do
  let(:data) do
    {
      "shango" => { "version" => 1 },
      "collection" => {
        "name" => "Pets", "description" => "d", "auth_type" => "bearer", "auth_config" => { "token" => "t" },
        "folders" => [{ "name" => "F", "auth_type" => "inherit", "auth_config" => {}, "folders" => [], "requests" => [{ "name" => "R", "http_method" => "POST", "url" => "/x", "auth_type" => "bogus" }] }],
        "requests" => []
      },
      "environments" => [{ "name" => "Dev", "variables" => [{ "key" => "a", "value" => "1", "secret" => true, "enabled" => false }] }]
    }
  end

  subject(:tree) { described_class.call(data:).record }

  it "builds the normalized tree", :aggregate_failures do
    collection = tree[:collections].first

    expect(collection).to include(name: "Pets", description: "d", auth_type: "bearer", auth_config: { "token" => "t" })
    expect(collection[:folders].first[:requests].first).to include(name: "R", http_method: "POST", url: "/x", auth_type: "inherit")
    expect(tree[:environments]).to eq([{ name: "Dev", variables: [{ key: "a", value: "1", secret: true, enabled: false }] }])
  end

  it "reads the scripts, assertions and extractors of every level", :aggregate_failures do
    automation = { "pre_request_script" => "// pre", "post_response_script" => "// post", "assertions" => [{ "source" => "status" }], "extractors" => [{ "variable" => "a" }] }
    data["collection"].merge!(automation)
    data["collection"]["folders"].first.merge!(automation)
    data["collection"]["folders"].first["requests"].first.merge!(automation)

    collection = tree[:collections].first
    expect(collection).to include(pre_request_script: "// pre", post_response_script: "// post", assertions: [{ "source" => "status" }], extractors: [{ "variable" => "a" }])
    expect(collection[:folders].first).to include(pre_request_script: "// pre", assertions: [{ "source" => "status" }])
    expect(collection[:folders].first[:requests].first).to include(post_response_script: "// post", extractors: [{ "variable" => "a" }])
  end

  it "has no automation keys when the export has none", :aggregate_failures do
    expect(tree[:collections].first.keys).not_to include(:pre_request_script, :post_response_script)
    expect(tree[:collections].first[:folders].first[:requests].first).to include(assertions: [], extractors: [])
  end

  it "warns about unsupported auth types" do
    expect(tree[:warnings]).to eq([I18n.t("workbench.imports.warnings.auth_unsupported", type: "bogus")])
  end

  it "needs no environments" do
    data.delete("environments")

    expect(tree[:environments]).to eq([])
  end
end
