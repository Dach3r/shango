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

    it "offers the timing breakdown", :aggregate_failures do
      stub_request(:get, url).to_return(status: 200, body: "ok")

      post workbench_request_executions_path(api_request), headers: turbo_headers

      expect(response.body).to include(I18n.t("workbench.executions.timing.title"), I18n.t("workbench.executions.timing.phases.ttfb"))
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

    it "stores the pending response and streams it back", :aggregate_failures do
      expect { post workbench_request_execution_saves_path(api_request, pending.id), headers: turbo_headers }.to change(RequestExecution, :count).by(1)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("response_panel")
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

    it "does not find executions of other requests" do
      execution = create(:request_execution, api_request: foreign_request)
      get workbench_request_execution_path(api_request, execution)

      expect(response).to have_http_status(:not_found)
    end
  end
end
