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
    it "tells a new draft to be saved before attaching files, and a saved request does not", :aggregate_failures do
      get workbench_request_path(draft.id)
      expect(response.body).to include(I18n.t("workbench.body.save_first"))
      expect(response.body).not_to include("api_request[binary_upload]")

      get workbench_request_path(api_request)
      expect(response.body).not_to include(I18n.t("workbench.body.save_first"))
      expect(response.body).to include("api_request[binary_upload]")
    end

    it "offers to monitor a saved request but not a draft", :aggregate_failures do
      get workbench_request_path(api_request)
      expect(response.body).to include(I18n.t("workbench.requests.monitor"), CGI.escapeHTML(new_monitoring_monitor_path(kind: "http", api_request_id: api_request.id)))

      get workbench_request_path(draft.id)
      expect(response.body).not_to include(I18n.t("workbench.requests.monitor"))
    end

    it "renders the editor", :aggregate_failures do
      get workbench_request_path(api_request)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(api_request.name)
    end

    it "replaces the page on refresh so saving keeps the editors and tabs", :aggregate_failures do
      get workbench_request_path(api_request)

      expect(response.body).to include(%(<meta name="turbo-refresh-method" content="replace">))
      expect(response.body).not_to include(%(content="morph"))
    end

    it "shows the collection and folder path of the request", :aggregate_failures do
      nested = create(:folder, collection:, parent: folder, name: "Deep")
      get workbench_request_path(create(:api_request, collection:, folder: nested, name: "Deep request"))

      expect(response.body.scan(%r{<span class="shrink-0 truncate">([^<]*)</span>}).flatten).to eq([collection.name, folder.name, "Deep"])
    end

    it "offers the other requests of the collection as response references, sorted by name", :aggregate_failures do
      create(:api_request, collection:, folder:, name: "beta", http_method: "POST")
      create(:api_request, collection:, name: "Alpha")
      create(:api_request, collection: foreign_collection, name: "Foreign")

      get workbench_request_path(api_request)

      references = response.body[/data-code-editor-responses-value="([^"]*)"/, 1]
      expect(JSON.parse(CGI.unescapeHTML(references)).map { |row| row.values_at("name", "method", "folder") }).to eq([["Alpha", "GET", nil], ["beta", "POST", folder.name]])
    end

    it "loads the environment variables once however many editors ask for them" do
      environment = create(:environment, project:)
      membership.update!(current_environment: environment)
      create_list(:variable, 3, environment:)
      get workbench_request_path(api_request)

      queries = []
      subscriber = ->(*, payload) { queries << payload[:sql] if payload[:sql].include?('FROM "variables"') }
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { get workbench_request_path(api_request) }

      expect(queries.size).to eq(1)
    end

    it "preloads the code editor only on the request page", :aggregate_failures do
      get workbench_root_path
      expect(response.body).to include("importmap")
      expect(response.body).not_to match(%r{<link rel="modulepreload" href="[^"]*codemirror})

      get workbench_request_path(api_request)
      expect(response.body).to match(%r{<link rel="modulepreload" href="[^"]*codemirror})
    end

    it "offers the cookie jar switch in the settings", :aggregate_failures do
      get workbench_request_path(api_request)

      expect(response.body).to include("api_request[settings][use_cookie_jar]", I18n.t("workbench.settings.use_cookie_jar"))
    end

    it "wires the max redirects field to the follow redirects switch", :aggregate_failures do
      get workbench_request_path(api_request)

      expect(response.body).to include("data-dependent-setting-target=\"switch\"", "data-dependent-setting-target=\"input\"", "data-dependent-setting-target=\"mirror\"")
    end

    it "keeps saved responses out of the body and lists them as history", :aggregate_failures do
      saved = create(:request_execution, api_request:, project:, user:, response_body: "hello-body")
      get workbench_request_path(api_request)

      expect(response.body).not_to include("hello-body")
      expect(response.body).to include(workbench_request_execution_path(api_request, saved))
    end

    it "shows no history list for a request without saved responses" do
      get workbench_request_path(api_request)

      expect(response.body).not_to include("/executions/")
    end

    it "shows the last unsaved response when coming back to the tab", :aggregate_failures do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      build(:request_execution, api_request:, project:, id: SecureRandom.uuid, user:, created_at: Time.current, response_body: "unsaved-body").stash
      get workbench_request_path(api_request)

      expect(response.body).to include("unsaved-body")
      expect(RequestExecution.where(api_request:)).not_to exist
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

    it "does not share its form id with the editor of the open request", :aggregate_failures do
      get new_workbench_collection_request_path(collection)

      expect(response.body).to include('id="new_request_form"', 'form="new_request_form"')
      expect(response.body).not_to include('id="request_form"')
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

    it "saves the cookie jar switch" do
      patch workbench_request_path(api_request), params: { api_request: { settings: { use_cookie_jar: "0" } } }

      expect(api_request.reload.setting(:use_cookie_jar)).to be(false)
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

  describe "edge cases" do
    it "requires authentication", :aggregate_failures do
      sign_out user
      get workbench_request_path(api_request)

      expect(response).to redirect_to(new_user_session_path)
    end

    it "does not create requests in collections of other projects", :aggregate_failures do
      expect { post workbench_collection_requests_path(foreign_collection), params: valid_params }.not_to change(ApiRequest, :count)
      expect(response).to have_http_status(:not_found)
    end

    it "rejects a folder of another collection on create", :aggregate_failures do
      other = create(:folder, collection: create(:collection, project:))
      params = { api_request: { name: "X", folder_id: other.id } }

      expect { post workbench_collection_requests_path(collection), params:, headers: turbo_headers }.not_to change(ApiRequest, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects a folder of another project on create" do
      post workbench_collection_requests_path(collection), params: { api_request: { name: "X", folder_id: foreign_folder.id } }, headers: turbo_headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects a folder that does not exist on create" do
      post workbench_collection_requests_path(collection), params: { api_request: { name: "X", folder_id: SecureRandom.uuid } }, headers: turbo_headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects a folder of another project on update", :aggregate_failures do
      patch workbench_request_path(api_request), params: { api_request: { folder_id: foreign_folder.id } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(api_request.reload.folder_id).to be_nil
    end

    it "rejects an unknown http method and body type" do
      patch workbench_request_path(api_request), params: { api_request: { http_method: "TRACE" } }
      expect(response).to have_http_status(:unprocessable_content)

      patch workbench_request_path(api_request), params: { api_request: { body_type: "yaml" } }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "does not reassign the project or collection through update", :aggregate_failures do
      patch workbench_request_path(api_request), params: { api_request: { name: "Same", project_id: foreign_collection.project_id, collection_id: foreign_collection.id } }

      expect(api_request.reload.project).to eq(project)
      expect(api_request.collection).to eq(collection)
    end

    it "does not update requests of other projects", :aggregate_failures do
      patch workbench_request_path(foreign_request), params: { api_request: { name: "Hacked" } }

      expect(response).to have_http_status(:not_found)
      expect(foreign_request.reload.name).not_to eq("Hacked")
    end

    it "does not destroy requests of other projects", :aggregate_failures do
      foreign_request
      expect { delete workbench_request_path(foreign_request) }.not_to change(ApiRequest, :count)
      expect(response).to have_http_status(:not_found)
    end

    it "does not update drafts of other users", :aggregate_failures do
      patch workbench_request_path(other_draft), params: { api_request: { name: "Hacked" } }

      expect(response).to have_http_status(:not_found)
      expect(other_draft.reload.name).not_to eq("Hacked")
    end

    it "does not destroy drafts of other users", :aggregate_failures do
      other_draft
      expect { delete workbench_request_path(other_draft) }.not_to change(RequestDraft, :count)
      expect(response).to have_http_status(:not_found)
    end

    it "does not open a tab for other users' drafts" do
      other_draft

      expect { get workbench_request_path(other_draft) }.not_to change(RequestTab, :count)
    end

    it "treats a malformed id as not found" do
      get workbench_request_path("nope")

      expect(response).to have_http_status(:not_found)
    end

    it "accepts unicode names and keeps duplicates", :aggregate_failures do
      post workbench_collection_requests_path(collection), params: { api_request: { name: "Ünïcode 日本 🚀" } }
      post workbench_collection_requests_path(collection), params: { api_request: { name: "Ünïcode 日本 🚀" } }

      expect(collection.api_requests.where(name: "Ünïcode 日本 🚀").count).to eq(2)
    end

    it "handles very long names and urls", :aggregate_failures do
      patch workbench_request_path(api_request), params: { api_request: { name: "n" * 5_000, url: "https://example.com/#{"a" * 20_000}" } }

      expect(response).to redirect_to(workbench_request_path(api_request))
      expect(api_request.reload.url.size).to be > 20_000
    end

    it "clamps out of range settings", :aggregate_failures do
      patch workbench_request_path(api_request), params: { api_request: { settings: { timeout: "-5", max_redirects: "9999" } } }

      expect(api_request.reload.setting(:timeout)).to eq(1)
      expect(api_request.setting(:max_redirects)).to eq(ApiRequest::MAX_REDIRECTS)
    end

    it "ignores nested garbage for row params", :aggregate_failures do
      patch workbench_request_path(api_request), params: { api_request: { headers: [{ key: "", value: "" }, { key: "A", value: "1" }], query_params: "oops" } }

      expect(response).to redirect_to(workbench_request_path(api_request))
      expect(api_request.reload.headers.pluck("key")).to eq(["A"])
    end

    it "rejects uploads over the size limit and keeps the request unchanged", :aggregate_failures do
      stub_const("ENV", ENV.to_h.merge("SHANGO_MAX_UPLOAD_MB" => "1"))
      big = Rack::Test::UploadedFile.new(StringIO.new("x" * 2.megabytes), "application/octet-stream", original_filename: "big.bin")
      patch workbench_request_path(api_request), params: { api_request: { name: "Changed", binary_upload: big } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(api_request.reload.binary_body).not_to be_attached
    end

    it "ignores upload tokens that match no row", :aggregate_failures do
      patch workbench_request_path(api_request), params: { api_request: { body_uploads: { "ghost" => fixture_file_upload("upload.txt", "text/plain") } } }

      expect(response).to redirect_to(workbench_request_path(api_request))
      expect(api_request.reload.body_files).not_to be_attached
    end

    it "does not ask for a placement when a saved request is updated with place", :aggregate_failures do
      patch workbench_request_path(api_request), params: { place: 1, api_request: { name: "Renamed" } }

      expect(response).to redirect_to(workbench_request_path(api_request))
    end

    it "destroys the request together with its tabs and executions", :aggregate_failures do
      create(:request_tab, user:, api_request:)
      create(:request_execution, api_request:, project:)
      delete workbench_request_path(api_request)

      expect(RequestTab.where(api_request_id: api_request.id)).not_to exist
      expect(RequestExecution.where(api_request_id: api_request.id)).not_to exist
    end
  end
end
