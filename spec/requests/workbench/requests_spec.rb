require "rails_helper"

RSpec.describe "Workbench requests" do
  include_context "with workbench project"

  let(:valid_params) do
    {
      api_request: {
        name: "List users", http_method: "POST", url: "https://api.example.com/users", body_type: "json", body: "{}",
        auth_type: "bearer", auth_config: { token: "abc" },
        settings: { timeout: "10", follow_redirects: "1" },
        query_params: [{ key: "page", value: "1", enabled: "true" }],
        headers: [{ key: "X-Test", value: "1" }]
      }
    }
  end

  describe "GET /workbench/requests/:id" do
    it "renders the editor", :aggregate_failures do
      get workbench_request_path(api_request)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(api_request.name)
    end

    it "renders the latest execution" do
      create(:request_execution, api_request:, project:, response_body: "hello-body")
      get workbench_request_path(api_request)

      expect(response).to have_http_status(:ok)
    end

    it "opens a tab for the request" do
      expect { get workbench_request_path(api_request) }.to change(RequestTab, :count).by(1)
    end

    it "does not open a tab on a prefetch", :aggregate_failures do
      expect { get workbench_request_path(api_request), headers: { "Sec-Purpose" => "prefetch" } }.not_to change(RequestTab, :count)
      expect { get workbench_request_path(api_request), headers: { "X-Sec-Purpose" => "prefetch" } }.not_to change(RequestTab, :count)
    end

    it "does not find requests of other projects" do
      get workbench_request_path(foreign_request)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /workbench/collections/:collection_id/requests/new" do
    it "renders the form", :aggregate_failures do
      get new_workbench_collection_request_path(collection, folder_id: folder.id)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /workbench/collections/:collection_id/requests" do
    it "creates the request", :aggregate_failures do
      expect { post workbench_collection_requests_path(collection), params: valid_params }.to change(collection.api_requests, :count).by(1)
      expect(response).to redirect_to(workbench_request_path(collection.api_requests.last))
    end

    it "re-renders the modal when invalid" do
      post workbench_collection_requests_path(collection), params: { api_request: { name: "" } }, headers: turbo_headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "works without any api_request params" do
      post workbench_collection_requests_path(collection), headers: turbo_headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /workbench/requests/:id" do
    it "updates the request", :aggregate_failures do
      patch workbench_request_path(api_request), params: valid_params

      expect(response).to redirect_to(workbench_request_path(api_request))
      expect(api_request.reload.name).to eq("List users")
    end

    it "stores uploaded files for multipart rows and a binary body", :aggregate_failures do
      token = "tok1"
      params = {
        api_request: {
          body_type: "multipart",
          body_form: [{ key: "file", value: "a.txt", type: "file", upload_token: token }],
          body_uploads: { token => fixture_file_upload("upload.txt", "text/plain") },
          binary_upload: fixture_file_upload("upload.txt", "text/plain")
        }
      }
      patch workbench_request_path(api_request), params: params

      expect(response).to redirect_to(workbench_request_path(api_request))
      expect(api_request.reload.binary_body).to be_attached
    end

    it "ignores non-file upload values" do
      patch workbench_request_path(api_request), params: { api_request: { name: "Same", body_uploads: { "t" => "plain" }, binary_upload: "plain" } }

      expect(response).to redirect_to(workbench_request_path(api_request))
    end

    it "ignores a scalar body_uploads value" do
      patch workbench_request_path(api_request), params: { api_request: { name: "Same", body_uploads: "nope" } }

      expect(response).to redirect_to(workbench_request_path(api_request))
    end

    it "re-renders the editor when invalid", :aggregate_failures do
      create(:request_execution, api_request:, project:)
      patch workbench_request_path(api_request), params: { api_request: { name: "" } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /workbench/requests/:id" do
    it "destroys the request", :aggregate_failures do
      api_request
      expect { delete workbench_request_path(api_request) }.to change(ApiRequest, :count).by(-1)
      expect(response).to redirect_to(workbench_root_path)
    end
  end
end
