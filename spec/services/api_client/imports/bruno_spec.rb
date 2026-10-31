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

  it "warns about file bodies, unknown items and unsupported auth", :aggregate_failures do
    expect(tree[:warnings]).to include(
      I18n.t("workbench.imports.warnings.file_body", name: "Multi"), I18n.t("workbench.imports.warnings.file_body", name: "File"),
      I18n.t("workbench.imports.warnings.unknown_item", type: "websocket-request"), I18n.t("workbench.imports.warnings.auth_unsupported", type: "wsse"),
      I18n.t("workbench.imports.warnings.auth_unsupported", type: "implicit")
    )
  end

  describe "scripts" do
    def request_for(raw)
      data = { "name" => "N", "items" => [{ "type" => "http-request", "name" => "r", "request" => { "url" => "http://x" }.merge(raw) }] }
      described_class.call(data:).record
    end

    it "translates the calls that have a Postman twin", :aggregate_failures do
      result = request_for("script" => { "req" => "bru.setVar('a', 1); const e = bru.getEnvVar('host'); bru.setEnvVar('b', 2); bru.getVar('a');", "res" => "console.log(res.status, res.getStatus());" }, "tests" => <<~JS)
        test("ok", function () { expect(res.status).to.equal(200); expect(res.body.id).to.exist; expect(res.getBody()).to.be.an("object"); expect(res.getHeader("x")).to.exist; expect(res.responseTime).to.be.below(1000); });
      JS
      request = result[:collections].first[:requests].first

      expect(request[:pre_request_script]).to eq("pm.variables.set('a', 1); const e = pm.environment.get('host'); pm.environment.set('b', 2); pm.variables.get('a');")
      expect(request[:post_response_script]).to include("console.log(pm.response.code, pm.response.code);", 'pm.test("ok", function () { pm.expect(pm.response.code).to.equal(200); pm.expect(pm.response.json().id).to.exist;', 'pm.response.headers.get("x")', "pm.response.responseTime")
      expect(result[:warnings].grep(/uses script features/)).to be_empty
    end

    it "keeps what it cannot translate and says so", :aggregate_failures do
      result = request_for("script" => { "req" => "req.setHeader('a', 'b'); bru.runRequest('x');" })

      expect(result[:collections].first[:requests].first[:pre_request_script]).to eq("req.setHeader('a', 'b'); bru.runRequest('x');")
      expect(result[:warnings]).to include(I18n.t("workbench.imports.warnings.scripts_unsupported", name: "r", apis: "bru.*, req.*"))
    end

    it "leaves out blank scripts" do
      expect(request_for("script" => { "req" => " ", "res" => "" }, "tests" => nil)[:collections].first[:requests].first.keys).not_to include(:pre_request_script, :post_response_script)
    end

    it "does not touch names that only look like the calls", :aggregate_failures do
      script = "obj.res.status; latest(1); my.expect(2); res.statusText; bru_x();"

      expect(ApiClient::Imports::BrunoScript.call(source: script)).to eq(script)
    end
  end

  it "handles API keys in the header and a collection without auth or environments", :aggregate_failures do
    data = { "name" => "N", "items" => [{ "type" => "http-request", "name" => "r", "request" => { "url" => "http://x", "auth" => { "mode" => "apikey", "apikey" => { "key" => "K", "value" => "V" } } } }] }
    result = described_class.call(data:).record
    expect(result[:collections].first[:requests].first[:auth_config]).to include("add_to" => "header")
    expect(result[:environments]).to eq([])
  end

  describe "malformed input" do
      def tree_for(data)
        described_class.call(data:).record
      end

      it "survives missing, non-array and non-object items", :aggregate_failures do
        expect(tree_for("name" => "x")[:collections].first[:requests]).to eq([])
        expect(tree_for("name" => "x", "items" => "x")[:collections].first[:requests]).to eq([])
        expect { tree_for("name" => "x", "items" => [{ "type" => "folder", "name" => "f", "items" => ["x"] }]) }.not_to raise_error
      end

      it "tolerates requests without a request object and non-numeric seq", :aggregate_failures do
        items = [{ "type" => "http-request", "name" => "r", "seq" => "a" }, { "type" => "http-request", "name" => "s", "seq" => nil, "request" => "x" }]

        expect(tree_for("name" => "x", "items" => items)[:collections].first[:requests].size).to eq(2)
      end

      it "ignores environments with non-object variables" do
        expect(tree_for("name" => "x", "environments" => [{ "name" => "e", "variables" => ["x"] }])[:environments].first[:variables]).to eq([])
      end
    end
end
