require "rails_helper"

RSpec.describe ApiClient::Imports::Openapi do
  def import(file)
    described_class.call(data: JSON.parse(file_fixture("imports/#{file}").read))
  end

  describe "OpenAPI 3" do
    subject(:tree) { import("openapi3.json").record }

    let(:collection) { tree[:collections].first }
    let(:pets) { collection[:folders].find { |folder| folder[:name] == "pets" } }
    let(:forms) { collection[:folders].find { |folder| folder[:name] == "forms" } }
    let(:root) { collection[:requests] }

    def find(list, name)
      list.find { |request| request[:name] == name }
    end

    it "builds the collection, tag folders and the baseUrl variable", :aggregate_failures do
      expect(collection).to include(name: "Petstore", description: "Pets")
      expect(collection[:folders].map { |folder| folder[:name] }).to eq(%w[pets forms])
      expect(tree[:environments]).to eq([{ name: "Petstore", variables: [{ key: "baseUrl", value: "https://api.pets.test/v1", secret: false, enabled: true }] }])
    end

    it "maps URL, params and headers", :aggregate_failures do
      list = find(pets[:requests], "List pets")
      expect(list).to include(http_method: "GET", url: "{{baseUrl}}/pets?limit=10", description: "All pets")
      expect(list[:query_params].map { |row| [row["key"], row["value"], row["enabled"]] }).to eq([["limit", "10", true], ["q", "[\"a\"]", false], ["obj", "{\"id\":0,\"kind\":\"a\"}", false], ["free", "string", false], ["shape", "{\"a\":\"string\"}", false]])
      expect(list[:headers].map { |row| row["key"] }).to eq(["X-Trace"])
      expect(find(root, "DELETE /pets/{petId}")[:url]).to eq("{{baseUrl}}/pets/{{petId}}")
    end

    it "generates JSON bodies from schemas", :aggregate_failures do
      body = JSON.parse(find(pets[:requests], "createPet")[:body])
      expect(find(pets[:requests], "createPet")).to include(body_type: "json")
      expect(body).to eq("name" => "Rex", "tags" => ["string"], "age" => 0, "ok" => false, "owner" => { "id" => 0, "kind" => "a" })
      expect(find(root, "POST /misc")[:body]).to eq("\"x\"")
      expect(JSON.parse(find(root, "PUT /misc")[:body])).to eq("self" => { "self" => { "self" => { "self" => { "self" => { "self" => nil } } } } })
      expect(find(root, "GET /misc")[:body]).to eq(JSON.pretty_generate("a" => 1))
      expect(find(root, "DELETE /misc")[:body]).to eq("")
      expect(find(root, "POST /jsonstr")[:body]).to eq("{\"a\":1}")
    end

    it "maps other body types", :aggregate_failures do
      expect(find(root, "PUT /pets/{petId}")).to include(body_type: "xml", body: "<pet/>")
      expect(find(root, "PATCH /pets/{petId}")).to include(body_type: "text", body: "hello")
      expect(find(forms[:requests], "POST /forms")[:body_form].map { |row| [row["key"], row["type"], row["value"]] }).to eq([%w[a text string], %w[n text 0]])
      expect(find(forms[:requests], "POST /forms")).to include(body_type: "form_urlencoded")
      expect(find(forms[:requests], "PUT /forms")).to include(body_type: "multipart")
      expect(find(forms[:requests], "PUT /forms")[:body_form]).to eq([{ "key" => "file", "value" => "", "enabled" => true, "description" => "", "type" => "file" }])
      expect(find(forms[:requests], "PATCH /forms")).to include(body_type: "none")
      expect(find(root, "PATCH /misc")).to include(body_type: "json", body: "")
    end

    it "maps security schemes", :aggregate_failures do
      expect(find(pets[:requests], "List pets")).to include(auth_type: "bearer")
      expect(find(pets[:requests], "createPet")).to include(auth_type: "basic")
      expect(find(pets[:requests], "GET /pets/{petId}")).to include(auth_type: "api_key", auth_config: { "key" => "X-Key", "add_to" => "header", "value" => "" }.slice("key", "add_to"))
      expect(find(root, "DELETE /pets/{petId}")[:auth_config]).to include("key" => "k", "add_to" => "query")
      expect(find(root, "PUT /pets/{petId}")).to include(auth_type: "inherit")
      expect(find(root, "PATCH /pets/{petId}")[:auth_config]).to include("grant_type" => "client_credentials", "token_url" => "https://pets.test/token", "scope" => "read write")
      expect(find(root, "HEAD /pets/{petId}")).to include(auth_type: "inherit")
      expect(find(root, "OPTIONS /pets/{petId}")).to include(auth_type: "inherit")
      expect(find(forms[:requests], "DELETE /forms")).to include(auth_type: "inherit")
      expect(find(forms[:requests], "POST /forms")).to include(auth_type: "inherit")
      expect(find(forms[:requests], "PUT /forms")).to include(auth_type: "inherit")
      expect(find(forms[:requests], "PATCH /forms")).to include(auth_type: "inherit")
    end

    it "warns about unsupported schemes and external references", :aggregate_failures do
      expect(tree[:warnings]).to include(I18n.t("workbench.imports.warnings.external_ref", ref: "https://other.test/schema.json"))
      %w[cookie oauth2_implicit openIdConnect http_digest unknown].each do |type|
        expect(tree[:warnings]).to include(I18n.t("workbench.imports.warnings.auth_unsupported", type:))
      end
    end
  end

  describe "Swagger 2" do
    subject(:tree) { import("swagger2.json").record }

    let(:requests) { tree[:collections].first[:folders].first[:requests] + tree[:collections].first[:requests] }

    it "builds the base URL from host, scheme and basePath", :aggregate_failures do
      expect(tree[:environments].first[:variables].first).to include(key: "baseUrl", value: "http://legacy.test/api")
      expect(tree[:collections].first[:folders].map { |folder| folder[:name] }).to eq(["items"])
    end

    it "maps body, form and query parameters", :aggregate_failures do
      by_name = requests.index_by { |request| request[:name] }
      expect(by_name["POST /items"]).to include(body_type: "json", auth_type: "basic")
      expect(JSON.parse(by_name["POST /items"][:body])).to eq("id" => 0)
      expect(by_name["PUT /items"]).to include(body_type: "form_urlencoded")
      expect(by_name["PATCH /items"][:body_form].first).to include("key" => "f", "type" => "file")
      expect(by_name["PATCH /items"]).to include(body_type: "multipart", auth_type: "oauth2")
      expect(by_name["PATCH /items"][:auth_config]).to include("grant_type" => "client_credentials")
      expect(by_name["GET /items"][:url]).to eq("{{baseUrl}}/items?q=string")
    end
  end

  describe "edge cases" do
    it "fails without paths", :aggregate_failures do
      result = described_class.call(data: { "openapi" => "3.0.0", "paths" => {} })
      expect(result).to be_failure
      expect(result.error).to eq(I18n.t("workbench.imports.errors.invalid_openapi"))
    end

    it "keeps relative URLs without a server and uses the default method defaults", :aggregate_failures do
      tree = described_class.call(data: { "openapi" => "3.0.0", "info" => { "title" => "T", "description" => "D" }, "paths" => { "/a" => { "get" => {} } } }).record
      expect(tree[:environments]).to eq([])
      expect(tree[:collections].first[:requests].first).to include(url: "/a", body_type: "none")
      expect(tree[:collections].first[:description]).to eq("D")
    end

    it "ignores servers without URL and swagger documents without a host", :aggregate_failures do
      expect(described_class.call(data: { "openapi" => "3", "servers" => [{}], "paths" => { "/a" => { "get" => {} } } }).record[:environments]).to eq([])
      expect(described_class.call(data: { "swagger" => "2.0", "paths" => { "/a" => { "get" => {} } } }).record[:environments]).to eq([])
    end

    it "defaults the swagger scheme to https and stops resolving circular references", :aggregate_failures do
      tree = described_class.call(data: { "swagger" => "2.0", "host" => "h.test", "paths" => { "/a" => { "get" => { "parameters" => [{ "$ref" => "#/parameters/A" }] } } }, "parameters" => { "A" => { "$ref" => "#/parameters/A" } } }).record
      expect(tree[:environments].first[:variables].first[:value]).to eq("https://h.test")
    end
  end
end
