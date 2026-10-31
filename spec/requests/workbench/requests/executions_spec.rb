require "rails_helper"

RSpec.describe "Workbench request executions" do
  include_context "with workbench project"

  let(:url) { "https://api.example.com/items" }

  before { allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new) }

  describe "POST /workbench/requests/:request_id/executions" do
    it "sends the request and streams the response panel without storing it", :aggregate_failures do
      stub_request(:get, url).to_return(status: 200, body: '{"ok":true}', headers: { "Content-Type" => "application/json" })

      expect { post workbench_request_executions_path(api_request), headers: turbo_headers }.not_to change(RequestExecution, :count)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("response_panel", I18n.t("workbench.executions.save"))
    end

    it "lists the outcome of assertions in a tests tab and saves extracted variables", :aggregate_failures do
      environment = create(:environment, project:)
      membership.update!(current_environment: environment)
      api_request.update!(assertions: [{ source: "status", operator: "equals", expected: "404" }], extractors: [{ source: "json", target: "$.id", variable: "item_id" }])
      stub_request(:get, url).to_return(status: 200, body: '{"id":5}', headers: { "Content-Type" => "application/json" })

      post workbench_request_executions_path(api_request), headers: turbo_headers

      expect(response.body).to include('data-name="tests"', "Status code equals 404", I18n.t("workbench.executions.tests.summary", passed: 1, failed: 1))
      expect(environment.variables.find_by(key: "item_id")&.value).to eq("5")
    end

    it "shows no tests tab for a request without assertions" do
      stub_request(:get, url).to_return(status: 200)

      post workbench_request_executions_path(api_request), headers: turbo_headers

      expect(response.body).not_to include('data-name="tests"')
    end

    it "offers the timing breakdown", :aggregate_failures do
      stub_request(:get, url).to_return(status: 200, body: "ok")

      post workbench_request_executions_path(api_request), headers: turbo_headers

      expect(response.body).to include(I18n.t("workbench.executions.timing.title"), I18n.t("workbench.executions.timing.phases.ttfb"))
      expect(response.body).to include('data-name="timing"', I18n.t("workbench.executions.timing.total"))
    end

    it "lists the cookies the response set in their own tab", :aggregate_failures do
      stub_request(:get, url).to_return(status: 200, headers: { "Set-Cookie" => ["_session=abc; Path=/; Secure; HttpOnly", "theme=dark; Max-Age=60", "last=1; Expires=Wed, 21 Oct 2037 07:28:00 GMT"] })

      post workbench_request_executions_path(api_request), headers: turbo_headers

      expect(response.body).to include('data-name="cookies"', "_session", "abc", "Secure, HttpOnly", "60 s", "Wed, 21 Oct 2037 07:28:00 GMT", I18n.t("workbench.executions.cookies.session"))
    end

    it "shows no cookies tab when the response sets none" do
      stub_request(:get, url).to_return(status: 200)

      post workbench_request_executions_path(api_request), headers: turbo_headers

      expect(response.body).not_to include('data-name="cookies"')
    end

    it "offers no save for failed requests", :aggregate_failures do
      stub_request(:get, url).to_raise(Errno::ECONNREFUSED)

      post workbench_request_executions_path(api_request), headers: turbo_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(I18n.t("workbench.executions.save"))
    end

    it "saves pending edits first", :aggregate_failures do
      stub_request(:post, url).to_return(status: 201, body: "created", headers: { "Content-Type" => "text/plain" })
      params = { api_request: { http_method: "POST", url:, body_type: "text", body: "x" } }

      post workbench_request_executions_path(api_request), params:, headers: turbo_headers

      expect(response).to have_http_status(:ok)
      expect(api_request.reload.http_method).to eq("POST")
    end

    it "refreshes the page after uploading files", :aggregate_failures do
      stub_request(:post, url).to_return(status: 200, body: "ok", headers: { "Content-Type" => "text/plain" })
      params = { api_request: { http_method: "POST", url:, body_type: "binary", binary_upload: fixture_file_upload("upload.txt", "text/plain") } }

      post workbench_request_executions_path(api_request), params:, headers: turbo_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('action="refresh"')
    end

    it "reports invalid edits", :aggregate_failures do
      post workbench_request_executions_path(api_request), params: { api_request: { name: "" } }, headers: turbo_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(RequestExecution.count).to eq(0)
    end

    it "does not find requests of other projects" do
      post workbench_request_executions_path(foreign_request), headers: turbo_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /workbench/requests/:request_id/executions/:execution_id/saves" do
    let(:pending) { build(:request_execution, id: SecureRandom.uuid, api_request:, project:, user:).stash }

    it "stores the pending response and leaves it to the history list", :aggregate_failures do
      expect { post workbench_request_execution_saves_path(api_request, pending.id), headers: turbo_headers }.to change(RequestExecution, :count).by(1)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("response_panel", workbench_request_execution_path(api_request, pending.id))
      expect(response.body).not_to include(%(data-name="body"))
      expect(RequestExecution.pending(pending.id)).to be_nil
    end

    it "is gone when the pending response expired", :aggregate_failures do
      post workbench_request_execution_saves_path(api_request, SecureRandom.uuid), headers: turbo_headers

      expect(response).to have_http_status(:gone)
      expect(RequestExecution.count).to eq(0)
    end

    it "does not save responses of other requests" do
      other = build(:request_execution, id: SecureRandom.uuid, api_request: create(:api_request, collection:), project:, user:).stash

      expect { post workbench_request_execution_saves_path(api_request, other.id), headers: turbo_headers }.not_to change(RequestExecution, :count)
    end
  end

  describe "GET /workbench/requests/:request_id/executions/:id" do
    it "renders the stored execution" do
      execution = create(:request_execution, api_request:, project:)
      get workbench_request_execution_path(api_request, execution)

      expect(response).to have_http_status(:ok)
    end

    it "offers searching the body only when there is one to search" do
      with_body = create(:request_execution, api_request:, project:, response_body: '{"a":1}')
      without_body = create(:request_execution, api_request:, project:, response_body: "")

      get workbench_request_execution_path(api_request, with_body)
      expect(response.body).to include('data-controller="response-search"')

      get workbench_request_execution_path(api_request, without_body)
      expect(response.body).not_to include('data-controller="response-search"')
    end

    it "does not find executions of other requests" do
      execution = create(:request_execution, api_request: foreign_request)
      get workbench_request_execution_path(api_request, execution)

      expect(response).to have_http_status(:not_found)
    end
  end
end

RSpec.describe "Workbench queued executions" do
  include_context "with workbench project"

  let(:state) { ApiClient::Executions::RunState }
  let(:run_id) { SecureRandom.uuid }
  let(:uploaded) { false }

  before do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    stub_const("ENV", ENV.to_h.merge("SHANGO_EXECUTION_MODE" => "async"))
  end

  describe "POST /workbench/requests/:request_id/executions" do
    it "queues the send and answers with the running panel", :aggregate_failures do
      expect { post workbench_request_executions_path(api_request), headers: turbo_headers }.to have_enqueued_job(RunRequestJob)

      expect(response).to have_http_status(:accepted)
      expect(response.headers["X-Execution-Id"]).to match(/\A\h{8}-/)
      expect(response.body).to include("response_panel", I18n.t("workbench.executions.running"))
      expect(state.read(response.headers["X-Execution-Id"])).to include("user_id" => user.id, "api_request_id" => api_request.id)
    end

    it "still saves pending edits and reports invalid ones", :aggregate_failures do
      post workbench_request_executions_path(api_request), params: { api_request: { name: "" } }, headers: turbo_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(RunRequestJob).not_to have_been_enqueued
    end
  end

  describe "GET /workbench/requests/:request_id/executions/:execution_id/result" do
    def start(**options)
      state.start(run_id, user_id: user.id, api_request_id: api_request.id, **options)
    end

    it "says 202 while the run is going", :aggregate_failures do
      start
      get workbench_request_execution_result_path(api_request, run_id), headers: turbo_headers

      expect(response).to have_http_status(:accepted)
      expect(response.body).to be_blank
    end

    it "streams the response panel once done", :aggregate_failures do
      start
      build(:request_execution, id: run_id, api_request:, project:, user:, created_at: Time.current, status: 200, response_body: "hi").stash
      state.finish(run_id, "done")
      get workbench_request_execution_result_path(api_request, run_id), headers: turbo_headers

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("response_panel", I18n.t("workbench.executions.save"))
      expect(response.body).not_to include('action="refresh"')
    end

    it "refreshes the page when the run uploaded files", :aggregate_failures do
      start(uploaded: true)
      build(:request_execution, id: run_id, api_request:, project:, user:, created_at: Time.current).stash
      state.finish(run_id, "done")
      get workbench_request_execution_result_path(api_request, run_id), headers: turbo_headers

      expect(response.body).to include('action="refresh"')
    end

    it "is gone when the response expired" do
      start
      state.finish(run_id, "done")
      get workbench_request_execution_result_path(api_request, run_id), headers: turbo_headers

      expect(response).to have_http_status(:gone)
    end

    it "has nothing to show for cancelled runs" do
      start
      state.finish(run_id, "cancelled")
      get workbench_request_execution_result_path(api_request, run_id), headers: turbo_headers

      expect(response).to have_http_status(:no_content)
    end

    it "reports failed runs" do
      start
      state.finish(run_id, "failed")
      get workbench_request_execution_result_path(api_request, run_id), headers: turbo_headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "is not found for unknown runs, other requests or other users", :aggregate_failures do
      get workbench_request_execution_result_path(api_request, SecureRandom.uuid), headers: turbo_headers
      expect(response).to have_http_status(:not_found)

      state.start(run_id, user_id: create(:user).id, api_request_id: api_request.id)
      get workbench_request_execution_result_path(api_request, run_id), headers: turbo_headers
      expect(response).to have_http_status(:not_found)

      state.start(run_id, user_id: user.id, api_request_id: api_request.id)
      get workbench_request_execution_result_path(create(:api_request, collection:), run_id), headers: turbo_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /workbench/requests/:request_id/executions/:execution_id/cancellation" do
    it "asks the worker to stop", :aggregate_failures do
      state.start(run_id, user_id: user.id, api_request_id: api_request.id)
      post workbench_request_execution_cancellation_path(api_request, run_id)

      expect(response).to have_http_status(:no_content)
      expect(state.cancelled?(run_id)).to be(true)
    end

    it "does not cancel runs of other users", :aggregate_failures do
      state.start(run_id, user_id: create(:user).id, api_request_id: api_request.id)
      post workbench_request_execution_cancellation_path(api_request, run_id)

      expect(response).to have_http_status(:not_found)
      expect(state.cancelled?(run_id)).to be(false)
    end
  end
end
