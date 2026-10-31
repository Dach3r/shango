require "rails_helper"

RSpec.describe ApiClient::Requests::Dispatch do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:environment) { create(:environment, project:) }
  let(:collection) { create(:collection, project:) }
  let(:api_request) { create(:api_request, collection:, url: "https://api.example.com/items", **attributes) }
  let(:attributes) { {} }
  let(:options) { {} }
  let(:result) { described_class.call(api_request:, environment:, user:, **options) }
  let(:execution) { result.record }

  before do
    create(:membership, :owner, user:, project:)
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
  end

  def reply(status: 200, body: "{}", url: "https://api.example.com/items", method: :get)
    stub_request(method, url).to_return(status:, body:, headers: { "Content-Type" => "application/json" })
  end

  describe "pre-request scripts" do
    let(:attributes) { { headers: [{ "key" => "X-Old", "value" => "1" }] } }

    it "can change the url, method, headers and body of what is sent, not of what is saved", :aggregate_failures do
      api_request.update!(pre_request_script: <<~JS, body_type: "json", body: "{}")
        pm.request.url = pm.request.url + "?via=script";
        pm.request.method = "POST";
        pm.request.headers.add({ key: "X-Script", value: "yes" });
        pm.request.headers.remove("X-Old");
        pm.request.body = JSON.stringify({ from: "script" });
      JS
      stub = stub_request(:post, "https://api.example.com/items?via=script").with(body: { from: "script" }.to_json, headers: { "X-Script" => "yes" }).to_return(status: 200)

      expect(execution).to have_attributes(status: 200, http_method: "POST", error_kind: nil)
      expect(stub).to have_been_requested
      expect(api_request.reload).to have_attributes(url: "https://api.example.com/items", http_method: "GET", body: "{}")
      expect(WebMock).not_to have_requested(:post, "https://api.example.com/items").with(headers: { "X-Old" => "1" })
    end

    it "can set variables the request uses", :aggregate_failures do
      api_request.update!(url: "https://api.example.com/{{path}}", pre_request_script: "pm.environment.set('path', 'dynamic'); pm.variables.set('other', 'x');")
      reply(url: "https://api.example.com/dynamic")

      expect(execution.status).to eq(200)
      expect(environment.variables.find_by(key: "path")&.value).to eq("dynamic")
      expect(result.data[:variables]).to include("path" => "dynamic", "other" => "x")
    end

    it "ignores a method that is not one of the allowed", :aggregate_failures do
      api_request.update!(pre_request_script: "pm.request.method = 'TRACE';")
      reply

      expect(execution.http_method).to eq("GET")
    end

    it "does not send anything when a script fails, and says why", :aggregate_failures do
      api_request.update!(pre_request_script: "console.log('before'); pm.test('t', () => {}); throw new Error('boom');")

      expect(execution).to have_attributes(status: nil, error_kind: "script_error", error_message: "Pre-request script of request #{api_request.name}: Error: boom")
      expect(execution.test_results.pluck("name", "status")).to eq([%w[t passed]])
      expect(execution.script_logs.pluck("text")).to eq(["before"])
      expect(WebMock).not_to have_requested(:get, "https://api.example.com/items")
    end

    it "keeps the failed tests of a script that then throws", :aggregate_failures do
      api_request.update!(pre_request_script: "pm.test('bad', () => { throw new Error('why'); }); throw new Error('boom');")

      expect(execution.test_results).to eq([{ "kind" => "script", "status" => "failed", "name" => "bad", "error" => "why" }])
    end

    it "masks secrets in what a failed script reports", :aggregate_failures do
      create(:variable, :secret, environment:, key: "token", value: "s3cr3t-value")
      api_request.update!(pre_request_script: "console.log(pm.environment.get('token')); throw new Error(pm.environment.get('token'));")

      expect(execution.error_message).to include(ApiClient::Masker::MASK)
      expect(execution.error_message).not_to include("s3cr3t-value")
      expect(execution.script_logs.first["text"]).to eq(ApiClient::Masker::MASK)
    end

    it "runs the scripts of the collection and folders first", :aggregate_failures do
      folder = create(:folder, collection:)
      api_request.update!(folder:, pre_request_script: "pm.environment.set('order', pm.environment.get('order') + 'r');")
      collection.update!(pre_request_script: "pm.environment.set('order', 'c');")
      folder.update!(pre_request_script: "pm.environment.set('order', pm.environment.get('order') + 'f');")
      reply

      execution

      expect(environment.variables.find_by(key: "order").value).to eq("cfr")
    end

    it "keeps the writes of a secret variable out of the logs of the request", :aggregate_failures do
      create(:variable, :secret, environment:, key: "token", value: "old-secret")
      api_request.update!(headers: [{ "key" => "Authorization", "value" => "Bearer {{token}}" }], pre_request_script: "pm.environment.set('token', 'new-secret-value');")
      stub_request(:get, "https://api.example.com/items").with(headers: { "Authorization" => "Bearer new-secret-value" }).to_return(status: 200, body: "echo new-secret-value")

      expect(execution.response_body).to eq("echo #{ApiClient::Masker::MASK}")
      expect(environment.variables.find_by(key: "token")).to be_secret
    end
  end

  describe "post-response scripts" do
    it "turn their tests into outcomes, with the console", :aggregate_failures do
      api_request.update!(post_response_script: <<~JS)
        console.log("status", pm.response.code);
        pm.test("is ok", () => pm.response.to.have.status(200));
        pm.test("has id", () => pm.expect(pm.response.json()).to.have.property("id"));
        pm.environment.set("seen_id", pm.response.json().id || "none");
      JS
      reply(body: "{}")

      expect(execution.test_results.map { |outcome| [outcome["kind"], outcome["status"], outcome["name"]] }).to eq([["script", "passed", "is ok"], ["script", "failed", "has id"]])
      expect(execution.script_logs).to eq([{ "level" => "log", "text" => "status 200" }])
      expect(environment.variables.find_by(key: "seen_id").value).to eq("none")
    end

    it "see the variables a pre-request script set" do
      api_request.update!(pre_request_script: "pm.variables.set('flag', 'on');", post_response_script: "pm.test('flag', () => pm.expect(pm.variables.get('flag')).to.equal('on'));")
      reply

      expect(execution.test_results.pluck("status")).to eq(["passed"])
    end

    it "report their own error as a failed outcome, still returning the response", :aggregate_failures do
      api_request.update!(post_response_script: "throw new Error('late');")
      reply

      expect(execution.status).to eq(200)
      expect(execution.test_results).to eq([{ "kind" => "script", "status" => "failed", "name" => nil, "error" => "Post-response script of request #{api_request.name}: Error: late" }])
      expect(execution.failed_tests).to eq(1)
    end

    it "run before the assertions and the extractors", :aggregate_failures do
      api_request.update!(
        post_response_script: "pm.test('script', () => {});", assertions: [{ source: "status", operator: "equals", expected: "200" }], extractors: [{ source: "status", variable: "code" }]
      )
      reply

      expect(execution.test_results.pluck("kind")).to eq(%w[script assertion extractor])
    end

    it "do not run when the request could not be sent", :aggregate_failures do
      api_request.update!(post_response_script: "pm.test('never', () => {});", pre_request_script: "pm.environment.set('kept', '1');")
      stub_request(:get, "https://api.example.com/items").to_timeout

      expect(execution.test_results).to eq([])
      expect(environment.variables.find_by(key: "kept")&.value).to eq("1")
    end

    it "mask secrets in test names, messages and the console", :aggregate_failures do
      create(:variable, :secret, environment:, key: "token", value: "s3cr3t-value")
      api_request.update!(post_response_script: <<~JS)
        console.log("token is " + pm.environment.get("token"));
        pm.test("name " + pm.environment.get("token"), () => { throw new Error(pm.environment.get("token")); });
      JS
      reply

      expect(execution.test_results.first.values_at("name", "error")).to eq(["name #{ApiClient::Masker::MASK}", ApiClient::Masker::MASK])
      expect(execution.script_logs.first["text"]).to eq("token is #{ApiClient::Masker::MASK}")
    end
  end

  describe "in a run" do
    let(:options) { { stash: false, persist: false, variables: { "carried" => "from-run" } } }

    it "sees the variables of the run and hands back what the scripts wrote without touching the environment", :aggregate_failures do
      api_request.update!(url: "https://api.example.com/{{carried}}", pre_request_script: "pm.environment.set('written', 'w'); pm.variables.set('local', 'l');")
      reply(url: "https://api.example.com/from-run")

      expect(execution.status).to eq(200)
      expect(execution).to be_new_record
      expect(result.data[:variables]).to include("written" => "w", "local" => "l")
      expect(environment.variables).to be_empty
    end
  end

  describe "the request as the scripts see it" do
    it "shows the saved request, variables unresolved, to a pre-request script", :aggregate_failures do
      create(:variable, environment:, key: "host", value: "api.example.com")
      api_request.update!(url: "https://{{host}}/items", pre_request_script: "pm.environment.set('seen_url', pm.request.url);")
      reply

      execution

      expect(environment.variables.find_by(key: "seen_url").value).to eq("https://{{host}}/items")
    end
  end
end
