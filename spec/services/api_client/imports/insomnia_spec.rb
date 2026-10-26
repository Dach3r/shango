require "rails_helper"

RSpec.describe ApiClient::Imports::Insomnia do
  def import(file)
    data = file.end_with?(".yaml") ? YAML.safe_load_file(file_fixture("imports/#{file}")) : JSON.parse(file_fixture("imports/#{file}").read)
    described_class.call(data:)
  end

  describe "v4 export" do
    subject(:tree) { import("insomnia_v4.json").record }

    let(:collection) { tree[:collections].first }
    let(:requests) { collection[:requests].index_by { |request| request[:name] } }
    let(:folder) { collection[:folders].first }

    it "builds the workspace tree ordered by sort key", :aggregate_failures do
      expect(collection).to include(name: "Shop", description: "Shop API")
      expect(folder).to include(name: "Orders", auth_type: "bearer")
      expect(folder[:folders].first).to include(name: "Nested", auth_type: "inherit")
      expect(folder[:requests].map { |request| request[:name] }).to eq(["List"])
    end

    it "maps URL, headers, params and variables", :aggregate_failures do
      list = folder[:requests].first
      expect(list).to include(http_method: "GET", url: "{{base}}/orders?page=1", description: "Lists orders")
      expect(list[:headers].map { |row| [row["key"], row["enabled"]] }).to eq([["X-A", true], ["X-B", false]])
    end

    it "maps body types", :aggregate_failures do
      expect(requests["Create"]).to include(body_type: "json", body: "{\"a\":1}", auth_type: "basic")
      expect(requests["Form"]).to include(body_type: "form_urlencoded")
      expect(requests["Multi"][:body_form].map { |row| [row["key"], row["type"], row["value"]] }).to eq([["f", "file", "a.png"], ["t", "text", "v"]])
      expect(requests["Graph"]).to include(body_type: "graphql", body: "{ a }", graphql_variables: "{\"x\":1}")
      expect(requests["Graph raw"]).to include(body_type: "graphql", body: "not json")
      expect(requests["Graph vars string"]).to include(graphql_variables: "{}")
      expect(requests["Bin"]).to include(body_type: "none")
      expect(requests["Text"]).to include(body_type: "text", body: "hi")
      expect(requests["Empty body"]).to include(body_type: "none")
    end

    it "maps authentication", :aggregate_failures do
      expect(requests["Form"]).to include(auth_type: "api_key", auth_config: { "key" => "K", "value" => "V", "add_to" => "query" })
      expect(requests["Multi"]).to include(auth_type: "digest")
      expect(requests["Graph"]).to include(auth_type: "aws_sigv4")
      expect(requests["Graph raw"]).to include(auth_type: "oauth2")
      expect(requests["Graph raw"][:auth_config]).to include("grant_type" => "client_credentials", "token_url" => "https://x.test/t")
      expect(requests["Graph vars string"]).to include(auth_type: "inherit")
      expect(requests["Bin"]).to include(auth_type: "none")
      expect(requests["Text"][:auth_config]).to eq("token" => "t", "prefix" => "Token")
      expect(requests["Empty body"]).to include(auth_type: "inherit")
      expect(requests["Ntlm"]).to include(auth_type: "inherit")
    end

    it "merges the base environment into each sub environment and flattens nested data", :aggregate_failures do
      expect(tree[:environments].map { |environment| environment[:name] }).to eq(["Dev"])
      expect(tree[:environments].first[:variables].to_h { |variable| [variable[:key], variable[:value]] }).to eq(
        "base" => "http://localhost", "db.host" => "h", "db.ports" => "[1,2]", "token" => "t"
      )
    end

    it "warns about unsupported features and file bodies", :aggregate_failures do
      expect(tree[:warnings]).to include(
        I18n.t("workbench.imports.warnings.file_body", name: "Multi"), I18n.t("workbench.imports.warnings.file_body", name: "Bin"),
        I18n.t("workbench.imports.warnings.auth_unsupported", type: "ntlm"), I18n.t("workbench.imports.warnings.auth_unsupported", type: "implicit")
      )
    end

    it "keeps a base-only environment under the workspace name and falls back without workspaces", :aggregate_failures do
      data = { "_type" => "export", "resources" => [
        { "_id" => "e", "_type" => "environment", "parentId" => nil, "name" => "Base", "data" => { "a" => "1" } },
        { "_id" => "r", "_type" => "request", "parentId" => nil, "name" => "R", "url" => "http://x" }
      ] }
      result = described_class.call(data:).record
      expect(result[:collections].first).to include(name: "Insomnia import")
      expect(result[:environments]).to eq([{ name: "Insomnia import", variables: [{ key: "a", value: "1", secret: false, enabled: true }] }])
    end

    it "covers minimal shapes", :aggregate_failures do
      data = { "_type" => "export", "resources" => [
        { "_id" => "w", "_type" => "workspace", "name" => "W" },
        { "_id" => "e", "_type" => "environment", "parentId" => "w", "name" => "B", "data" => { "a" => "1" } },
        { "_id" => "s", "_type" => "environment", "parentId" => "e", "name" => "Sub" },
        { "_id" => "g", "_type" => "request", "parentId" => "w", "name" => "G", "body" => { "mimeType" => "application/graphql", "text" => "{\"query\":\"{ a }\"}" },
          "authentication" => { "type" => "apikey", "key" => "K", "value" => "V" } }
      ] }
      result = described_class.call(data:).record
      request = result[:collections].first[:requests].first
      expect(request).to include(body: "{ a }", graphql_variables: nil)
      expect(request[:auth_config]).to include("add_to" => "header")
      expect(result[:environments].first[:variables]).to eq([{ key: "a", value: "1", secret: false, enabled: true }])
    end

    it "skips empty base environments" do
      data = { "_type" => "export", "resources" => [{ "_id" => "w", "_type" => "workspace", "name" => "W" }, { "_id" => "e", "_type" => "environment", "parentId" => "w", "data" => {} }] }
      expect(described_class.call(data:).record[:environments]).to eq([])
    end

    it "ignores workspaces without environments" do
      expect(described_class.call(data: { "_type" => "export", "resources" => [{ "_id" => "w", "_type" => "workspace", "name" => "W" }] }).record[:environments]).to eq([])
    end
  end

  describe "v5 export" do
    subject(:tree) { import("insomnia_v5.yaml").record }

    it "builds nested folders and requests", :aggregate_failures do
      collection = tree[:collections].first
      expect(collection[:name]).to eq("Blog")
      expect(collection[:folders].first[:name]).to eq("Posts")
      expect(collection[:folders].first[:folders].first[:name]).to eq("Deep")
      expect(collection[:folders].first[:requests].first).to include(url: "{{base}}/posts/1", auth_type: "bearer", body_type: "none")
      expect(collection[:requests].first).to include(name: "Create post", body_type: "json")
    end

    it "expands sub environments over the base", :aggregate_failures do
      expect(tree[:environments]).to eq([{ name: "Local", variables: [{ key: "base", value: "http://localhost:3000", secret: false, enabled: true }] }])
    end

    it "handles a collection without environments", :aggregate_failures do
      result = described_class.call(data: { "type" => "collection.insomnia.rest/5.0", "name" => "N", "collection" => [] })
      expect(result.record[:environments]).to eq([])
    end
  end
end
