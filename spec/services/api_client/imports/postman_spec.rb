require "rails_helper"

RSpec.describe ApiClient::Imports::Postman do
  def import(file)
    described_class.call(data: JSON.parse(file_fixture("imports/#{file}").read))
  end

  describe "collection" do
    subject(:tree) { import("postman_collection.json").record }

    let(:collection) { tree[:collections].first }
    let(:folder) { collection[:folders].first }
    let(:requests) { collection[:requests].index_by { |request| request[:name] } }

    it "builds the collection, folders and variables environment", :aggregate_failures do
      expect(collection).to include(name: "Pets", description: "Pet store")
      expect(folder).to include(name: "Pets", auth_type: "basic", auth_config: { "username" => "u", "password" => "p" })
      expect(folder[:requests].map { |request| request[:name] }).to eq(["List pets", "Create pet"])
      expect(tree[:environments]).to eq([{ name: "Pets variables", variables: [{ key: "baseUrl", value: "https://api.example.com", secret: false, enabled: true }] }])
    end

    it "maps URL, params, headers and dynamic variables", :aggregate_failures do
      list = folder[:requests].first
      expect(list).to include(http_method: "GET", url: "{{baseUrl}}/pets?limit=10", auth_type: "inherit")
      expect(list[:query_params].map { |row| [row["key"], row["enabled"]] }).to eq([["limit", true], ["page", false]])
      expect(list[:headers].map { |row| [row["key"], row["value"], row["enabled"]] }).to eq([["X-Trace", "{{$guid}}", true], ["X-Off", "1", false]])
    end

    it "parses params from a raw URL and keeps request details", :aggregate_failures do
      create = folder[:requests].last
      expect(create).to include(auth_type: "none", description: "Creates", body_type: "json", body: "{\"name\":\"Rex\"}", url: "{{baseUrl}}/pets?dry=1")
      expect(create[:query_params].first).to include("key" => "dry", "value" => "1")
    end

    it "pushes the collection auth down to top-level requests without their own", :aggregate_failures do
      expect(requests["Form"]).to include(auth_type: "bearer", auth_config: { "token" => "{{token}}", "prefix" => "Bearer" })
      expect(requests["Form"][:url]).to eq("https://api.example.com/form")
    end

    it "maps body modes", :aggregate_failures do
      expect(requests["Form"]).to include(body_type: "form_urlencoded")
      expect(requests["Form"][:body_form].map { |row| row["key"] }).to eq(["a"])
      expect(requests["Upload"]).to include(body_type: "multipart")
      expect(requests["Upload"][:body_form].map { |row| [row["key"], row["type"], row["value"]] }).to eq([["f", "file", "a.png"], ["t", "text", "v"]])
      expect(requests["Graph"]).to include(body_type: "graphql", body: "{ a }", graphql_variables: "{}")
      expect(requests["Binary"]).to include(body_type: "none")
      expect(requests["Text"]).to include(body_type: "text", body: "hi")
      expect(requests["Empty body"]).to include(body_type: "none")
      expect(requests["String request"]).to include(url: "https://x.test/s", http_method: "GET")
    end

    it "maps auth strategies", :aggregate_failures do
      expect(requests["Key"]).to include(auth_type: "api_key", auth_config: { "key" => "X-K", "value" => "v", "add_to" => "query" })
      expect(requests["Digest"]).to include(auth_type: "digest", auth_config: { "username" => "u" })
      expect(requests["Aws"]).to include(auth_type: "aws_sigv4")
      expect(requests["Aws"][:auth_config]).to include("access_key" => "ak", "region" => "us-east-1")
      expect(requests["OAuth"]).to include(auth_type: "oauth2")
      expect(requests["OAuth"][:auth_config]).to include("grant_type" => "client_credentials", "token_url" => "https://x.test/token")
      expect(requests["OAuth token"]).to include(auth_type: "bearer", auth_config: { "token" => "tok", "prefix" => "Bearer" })
      expect(requests["Hawk"]).to include(auth_type: "inherit")
    end

    it "warns about file bodies and unsupported auth", :aggregate_failures do
      expect(tree[:warnings]).to include(
        I18n.t("workbench.imports.warnings.file_body", name: "Upload"), I18n.t("workbench.imports.warnings.file_body", name: "Binary"),
        I18n.t("workbench.imports.warnings.auth_unsupported", type: "hawk")
      )
    end

    it "keeps the scripts of the requests and folders, with no warning when Shango can run them", :aggregate_failures do
      collection = tree[:collections].first
      pets = collection[:folders].find { |folder| folder[:name] == "Pets" }

      expect(pets).to include(pre_request_script: "console.log(1)")
      expect(pets[:requests].find { |request| request[:name] == "List pets" }).to include(post_response_script: "pm.test('ok')")
      expect(tree[:warnings].grep(/script/)).to be_empty
    end
  end

  describe "scripts" do
    def build(data)
      described_class.call(data: { "info" => { "name" => "N" } }.merge(data))
    end

    it "joins the lines of an event and the events of one kind, and keeps collection level scripts", :aggregate_failures do
      event = [
        { "listen" => "prerequest", "script" => { "exec" => %w[a b] } }, { "listen" => "prerequest", "script" => { "exec" => "c" } },
        { "listen" => "test", "script" => { "exec" => ["t"] } }, { "listen" => "other", "script" => { "exec" => ["x"] } }, "junk"
      ]
      collection = build("event" => event, "item" => []).record[:collections].first

      expect(collection).to include(pre_request_script: "a\nb\nc", post_response_script: "t")
    end

    it "has no script keys when there are none or they are blank", :aggregate_failures do
      collection = build("event" => [{ "listen" => "test", "script" => { "exec" => ["  "] } }], "item" => []).record[:collections].first

      expect(collection.keys).not_to include(:pre_request_script, :post_response_script)
    end

    it "reports the calls Shango's pm does not have, naming them", :aggregate_failures do
      item = { "name" => "Login", "event" => [{ "listen" => "test", "script" => { "exec" => ["pm.sendRequest('x', () => {});", "const h = CryptoJS.MD5('a');", "_.get(a, 'b');", "postman.setNextRequest(null);"] } }], "request" => { "url" => "http://x" } }
      request = build("item" => [item]).record[:collections].first[:requests].first

      expect(request[:post_response_script]).to include("pm.sendRequest")
      expect(build("item" => [item]).record[:warnings]).to include(I18n.t("workbench.imports.warnings.scripts_unsupported", name: "Login", apis: "pm.sendRequest, postman.*, CryptoJS, lodash"))
    end

    it "skips non-object items and collections without variables", :aggregate_failures do
      result = described_class.call(data: { "info" => { "name" => "N" }, "item" => ["junk", { "name" => "r", "request" => { "url" => "http://x" } }] })
      expect(result.record[:collections].first[:requests].size).to eq(1)
      expect(result.record[:environments]).to eq([])
    end
  end

  describe "minimal shapes" do
    def build(items)
      described_class.call(data: { "info" => { "name" => "N" }, "item" => items }).record[:collections].first
    end

    it "leaves folders inheriting when nothing above sets auth", :aggregate_failures do
      folder = build([{ "name" => "F", "item" => [] }]).fetch(:folders).first
      expect(folder).to include(auth_type: "inherit")
    end

    it "builds URLs from host and path parts without protocol or path", :aggregate_failures do
      requests = build([
        { "name" => "a", "request" => { "url" => { "host" => %w[x test] } } },
        { "name" => "b", "request" => { "url" => { "host" => ["x"], "path" => ["p"] } } }
      ]).fetch(:requests)
      expect(requests.map { |request| request[:url] }).to eq(["x.test", "x/p"])
    end

    it "places API keys in the header by default" do
      auth = { "type" => "apikey", "apikey" => [{ "key" => "key", "value" => "K" }, { "key" => "value", "value" => "v" }] }
      request = build([{ "name" => "a", "request" => { "url" => "http://x", "auth" => auth } }]).fetch(:requests).first
      expect(request[:auth_config]).to include("add_to" => "header")
    end
  end

  describe "environment" do
    it "imports enabled flags and secrets", :aggregate_failures do
      tree = import("postman_environment.json").record
      expect(tree[:collections]).to eq([])
      expect(tree[:environments]).to eq([{ name: "Staging", variables: [
        { key: "host", value: "https://staging.example.com", secret: false, enabled: true },
        { key: "apiKey", value: "s3cret", secret: true, enabled: true },
        { key: "old", value: "x", secret: false, enabled: false }
      ] }])
    end
  end

  describe "malformed input" do
      def tree_for(item, extra = {})
        described_class.call(data: { "info" => { "name" => "C" }, "item" => [item] }.merge(extra)).record
      end

      it "survives requests given as strings, nil or with odd members", :aggregate_failures do
        expect(tree_for({ "name" => "a", "request" => "http://x" })[:collections].first[:requests].first[:url]).to eq("http://x")
        expect(tree_for({ "request" => nil })[:collections].first[:requests].first[:name]).to eq("Untitled request")
        expect { tree_for({ "name" => "a", "request" => { "header" => ["a: b"], "url" => { "query" => ["x"] } } }) }.not_to raise_error
        expect { tree_for({ "name" => "a", "request" => { "url" => 5, "method" => 5 } }) }.not_to raise_error
      end

      it "keeps duplicate and unnamed items" do
        tree = described_class.call(data: { "info" => {}, "item" => [{ "name" => "r", "request" => {} }, { "name" => "r", "request" => {} }] }).record

        expect(tree[:collections].first[:requests].size).to eq(2)
      end

      it "does not trust variables that are not objects" do
        expect(described_class.call(data: { "values" => ["x"], "name" => "e" }).record[:environments].first[:variables]).to eq([])
      end
    end
end
