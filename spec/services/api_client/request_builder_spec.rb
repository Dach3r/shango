require "rails_helper"

RSpec.describe ApiClient::RequestBuilder do
  subject(:result) { described_class.call(api_request:, environment:, dry_run: true) }

  let(:collection) { create(:collection) }
  let(:environment) { nil }
  let(:attributes) { {} }
  let(:api_request) { create(:api_request, { collection:, auth_type: "none", url: "https://api.example.com/items" }.merge(attributes)) }
  let(:built) { result.record }

  describe "response references" do
    subject(:result) { described_class.call(api_request:, environment:, dry_run: true, user:) }

    let(:user) { create(:user) }
    let(:source) { create(:api_request, collection:) }
    let(:attributes) do
      { url: "https://api.example.com/items/{{response.body.#{source.id}.$.id}}", headers: [{ "key" => "X-Echo", "value" => "{{response.body.#{source.id}.$.note}}" }] }
    end

    before do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      create(:request_execution, api_request: source, user:, response_body: '{"id":638,"note":"{{secret}}"}')
    end

    it "fills values from the latest response of a request in the collection", :aggregate_failures do
      expect(built.url).to eq("https://api.example.com/items/638")
      expect(built.unresolved).to be_empty
    end

    it "does not let a response inject variable references" do
      expect(built.headers["X-Echo"]).to eq("{ {secret}}")
    end

    context "without a response yet" do
      before { source.request_executions.destroy_all }

      it "aborts on the url", :aggregate_failures do
        expect(result).to be_failure
        expect(result.data[:unresolved]).to eq(["response.body.#{source.id}.$.id"])
      end
    end

    context "without a user" do
      subject(:result) { described_class.call(api_request:, environment:, dry_run: true) }

      it "leaves the reference unresolved" do
        expect(result).to be_failure
      end
    end
  end

  describe "url" do
    it "builds a successful result", :aggregate_failures do
      expect(result).to be_success
      expect(built).to have_attributes(
        http_method: "GET", url: "https://api.example.com/items", timeout: 30, follow_redirects: true,
        max_redirects: 5, verify_ssl: true, unresolved: [], secrets: []
      )
    end

    context "with a blank url" do
      let(:attributes) { { url: "  " } }

      it "fails", :aggregate_failures do
        expect(result).to be_failure
        expect(result.error).to eq(I18n.t("workbench.errors.blank_url"))
      end
    end

    context "without a scheme" do
      let(:attributes) { { url: "api.example.com/x" } }

      it "defaults to http" do
        expect(built.url).to eq("http://api.example.com/x")
      end
    end

    context "with an unresolved variable" do
      let(:attributes) { { url: "{{host}}/x" } }

      it "fails and reports it", :aggregate_failures do
        expect(result.error).to eq(I18n.t("workbench.errors.unresolved_url", names: "host"))
        expect(result.data[:unresolved]).to eq(["host"])
      end
    end

    context "with a non http scheme" do
      let(:attributes) { { url: "ftp://a.test" } }

      it "fails" do
        expect(result.error).to eq(I18n.t("workbench.errors.invalid_url"))
      end
    end

    context "with a malformed url" do
      let(:attributes) { { url: "http://a b" } }

      it "fails" do
        expect(result.error).to eq(I18n.t("workbench.errors.invalid_url"))
      end
    end
  end

  describe "environment" do
    let(:environment) { create(:environment, project: collection.project) }
    let(:attributes) { { url: "https://{{host}}/x", headers: [{ "key" => "X-Token", "value" => "{{token}}" }] } }

    before do
      create(:variable, environment:, key: "host", value: "api.test")
      create(:variable, :secret, environment:, key: "token", value: "tok-123")
    end

    it "resolves variables and collects secrets", :aggregate_failures do
      expect(built.url).to eq("https://api.test/x")
      expect(built.headers["X-Token"]).to eq("tok-123")
      expect(built.secrets).to eq(["tok-123"])
    end
  end

  describe "environment scoping" do
    let(:environment) { create(:environment, project: collection.project) }
    let(:attributes) { { url: "https://{{host}}/x" } }

    it "does not resolve variables of other environments or projects", :aggregate_failures do
      create(:variable, environment: create(:environment, project: collection.project), key: "host", value: "sibling.test")
      create(:variable, environment: create(:environment), key: "host", value: "foreign.test")

      expect(result).to be_failure
      expect(result.data[:unresolved]).to eq(["host"])
    end

    it "copes with a blank secret variable", :aggregate_failures do
      create(:variable, environment:, key: "host", value: "api.test")
      create(:variable, :secret, environment:, key: "empty", value: "")

      expect(built.url).to eq("https://api.test/x")
      expect(built.secrets.map(&:to_s)).to all(be_a(String))
    end

    context "with a variable holding variable syntax" do
      let(:attributes) { { url: "https://{{host}}/x", headers: [{ "key" => "X-A", "value" => "{{a}}" }] } }

      it "resolves chains across variables of the same environment", :aggregate_failures do
        create(:variable, environment:, key: "host", value: "{{sub}}.test")
        create(:variable, environment:, key: "sub", value: "api")
        create(:variable, environment:, key: "a", value: "{{missing}}")

        expect(built.url).to eq("https://api.test/x")
        expect(built.headers["X-A"]).to eq("{{missing}}")
        expect(built.unresolved).to eq(["missing"])
      end
    end
  end

  describe "headers" do
    let(:attributes) do
      { headers: [
        { "key" => "X-A", "value" => "1" }, { "key" => "x-a", "value" => "2" }, { "key" => "Off", "value" => "v", "enabled" => false },
        { "key" => "user-agent", "value" => "custom" }
      ] }
    end

    it "keeps enabled rows, joins duplicates and adds missing defaults", :aggregate_failures do
      expect(built.headers).to eq("X-A" => "1", "x-a" => "2", "user-agent" => "custom", "Accept" => "*/*")
      expect(built.defaults_added).to eq(["Accept"])
    end

    context "with the same name twice" do
      let(:attributes) { { headers: [{ "key" => "X-A", "value" => "1" }, { "key" => "X-A", "value" => "2" }] } }

      it "joins values" do
        expect(built.headers["X-A"]).to eq("1, 2")
      end
    end
  end

  describe "body" do
    let(:attributes) { { http_method: "POST", body_type:, body: '{"a":1}' } }
    let(:body_type) { "json" }

    it "builds json bodies", :aggregate_failures do
      expect(built.body.factory.call).to eq('{"a":1}')
      expect(built.body.preview).to eq('{"a":1}')
      expect(built.headers["Content-Type"]).to eq("application/json")
    end

    context "with an explicit content type" do
      let(:attributes) { { http_method: "POST", body_type:, body: "x", headers: [{ "key" => "content-type", "value" => "application/vnd.x" }] } }

      it "keeps it" do
        expect(built.headers).not_to have_key("Content-Type")
      end
    end

    context "when body_type is none" do
      let(:body_type) { "none" }

      it "has an empty body", :aggregate_failures do
        expect(built.body.factory.call).to be_nil
        expect(built.body.preview).to be_nil
      end
    end

    context "when method is GET" do
      let(:attributes) { { http_method: "GET", body_type:, body: "x" } }

      it "ignores the body" do
        expect(built.body.preview).to be_nil
      end
    end

    context "with text and xml" do
      let(:body_type) { "xml" }

      it "sets the content type" do
        expect(built.headers["Content-Type"]).to eq("application/xml")
      end
    end

    context "with graphql" do
      let(:body_type) { "graphql" }
      let(:attributes) { { http_method: "POST", body_type:, body: "{ me }", graphql_variables: '{"id":1}' } }

      it "builds the payload", :aggregate_failures do
        expect(JSON.parse(built.body.preview)).to eq("query" => "{ me }", "variables" => { "id" => 1 })
        expect(built.headers["Content-Type"]).to eq("application/json")
      end

      it "defaults variables to an empty object" do
        api_request.update!(graphql_variables: "")

        expect(JSON.parse(built.body.preview)["variables"]).to eq({})
      end

      it "fails on invalid variables", :aggregate_failures do
        api_request.update!(graphql_variables: "{")

        expect(result).to be_failure
        expect(result.error).to eq(I18n.t("workbench.errors.invalid_graphql_variables"))
      end
    end

    context "with form_urlencoded" do
      let(:body_type) { "form_urlencoded" }
      let(:attributes) do
        { http_method: "POST", body_type:, body_form: [{ "key" => "a", "value" => "1 2" }, { "key" => "f", "value" => "x", "type" => "file" }, { "key" => "off", "value" => "1", "enabled" => false }] }
      end

      it "encodes enabled non file rows", :aggregate_failures do
        expect(built.body.preview).to eq("a=1+2")
        expect(built.headers["Content-Type"]).to eq("application/x-www-form-urlencoded")
      end
    end

    context "with form_urlencoded special characters" do
      let(:body_type) { "form_urlencoded" }
      let(:attributes) do
        { http_method: "POST", body_type:, body_form: [{ "key" => "q&x", "value" => "a=b&c=d" }, { "key" => "u", "value" => "ñandú 🦤" }, { "key" => "", "value" => "blank key" }] }
      end

      it "percent encodes keys and values and skips blank keys" do
        expect(built.body.preview).to eq("q%26x=a%3Db%26c%3Dd&u=%C3%B1and%C3%BA+%F0%9F%A6%A4")
      end
    end

    context "with disabled rows holding unknown variables" do
      let(:attributes) { { headers: [{ "key" => "X-Off", "value" => "{{nope}}", "enabled" => false }] } }

      it "does not report them", :aggregate_failures do
        expect(built.unresolved).to be_empty
        expect(built.headers).not_to have_key("X-Off")
      end
    end

    context "with json containing variables inside strings" do
      let(:environment) { create(:environment, project: collection.project) }
      let(:attributes) { { http_method: "POST", body_type: "json", body: '{"name":"{{who}}","n":{{count}}}' } }

      it "inserts values as text without touching the surrounding json", :aggregate_failures do
        create(:variable, environment:, key: "who", value: "Ana")
        create(:variable, environment:, key: "count", value: "3")

        expect(JSON.parse(built.body.preview)).to eq({ "name" => "Ana", "n" => 3 })
      end
    end

    context "with multipart" do
      let(:body_type) { "multipart" }
      let(:attributes) { { http_method: "POST", body_type: } }
      let(:rows) do
        [
          { "key" => "name", "value" => "ada" },
          { "key" => "doc", "type" => "file", "attachment_id" => api_request.body_files.first.id.to_s },
          { "key" => "off", "value" => "x", "enabled" => false }
        ]
      end

      before do
        api_request.body_files.attach(io: StringIO.new("data"), filename: "a.txt", content_type: "text/plain")
        api_request.update!(body_form: rows)
      end

      it "previews the form", :aggregate_failures do
        expect(built.body.multipart).to be(true)
        expect(built.body.preview).to eq("name=ada\ndoc=@a.txt")
        expect(built.body.form).to eq([["name", "ada"], ["doc", "@a.txt"]])
        expect(built.headers["Content-Type"]).to eq("multipart/form-data")
      end

      it "builds the parts lazily", :aggregate_failures do
        parts = built.body.factory.call

        expect(parts["name"]).to eq("ada")
        expect(parts["doc"]).to be_a(Faraday::Multipart::FilePart)
        expect(parts["doc"].content_type).to eq("text/plain")
      end

      it "defaults the content type of files" do
        api_request.body_files.first.blob.update!(content_type: nil)

        expect(built.body.factory.call["doc"].content_type).to eq("application/octet-stream")
      end
    end

    context "with binary" do
      let(:body_type) { "binary" }

      it "fails without a file", :aggregate_failures do
        expect(result).to be_failure
        expect(result.error).to eq(I18n.t("workbench.errors.missing_binary"))
      end

      it "reads the attached file", :aggregate_failures do
        api_request.binary_body.attach(io: StringIO.new("bin"), filename: "b.bin", content_type: "application/pdf")

        expect(built.body.factory.call).to eq("bin")
        expect(built.body.preview).to eq("[binary b.bin · 3 bytes]")
        expect(built.headers["Content-Type"]).to eq("application/pdf")
      end

      it "defaults the content type" do
        api_request.binary_body.attach(io: StringIO.new("bin"), filename: "b.bin", content_type: "")

        expect(built.headers["Content-Type"]).to eq("application/octet-stream")
      end
    end

    context "with an unknown body type" do
      it "builds an empty body" do
        allow(api_request).to receive(:body_type).and_return("weird")

        expect(built.body.preview).to be_nil
      end
    end
  end

  describe "auth" do
    let(:attributes) { { auth_type: "bearer", auth_config: { "token" => "{{t}}" } } }
    let(:environment) { create(:environment, project: collection.project) }

    before { create(:variable, environment:, key: "t", value: "abc") }

    it "applies the resolved strategy", :aggregate_failures do
      expect(built.headers["Authorization"]).to eq("Bearer abc")
      expect(built.auth).to be_a(ApiClient::Auth::Bearer)
    end

    context "when the config is incomplete" do
      let(:attributes) { { auth_type: "bearer", auth_config: {} } }

      it "fails" do
        expect(result.error).to eq("Missing token")
      end
    end
  end
end
