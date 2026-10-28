require "rails_helper"

RSpec.describe "Authorization" do
  let(:project) { create(:project) }
  let(:member) { create(:user) }
  let(:alert) { I18n.t("authorization.forbidden") }
  let(:json_headers) { { "Accept" => "application/json" } }
  let(:collection) { create(:collection, project:) }
  let!(:folder) { create(:folder, collection:) }
  let!(:api_request) { create(:api_request, collection:) }
  let(:environment) { create(:environment, project:) }

  before do
    create(:membership, :owner, project:)
    membership = create(:membership, user: member, project:)
    member.update!(current_membership: membership)
    sign_in member
  end

  def expect_forbidden
    expect(response).to redirect_to(workbench_root_path)
    expect(flash[:alert]).to eq(alert)
  end

  describe "collections" do
    it "keeps members from editing or deleting a collection they did not create", :aggregate_failures do
      get edit_workbench_collection_path(collection)
      expect_forbidden

      patch workbench_collection_path(collection), params: { collection: { name: "Hacked" } }
      expect_forbidden

      expect { delete workbench_collection_path(collection) }.not_to change(Collection, :count)
      expect_forbidden
      expect(collection.reload.name).not_to eq("Hacked")
    end

    it "lets members create collections and manage the ones they created", :aggregate_failures do
      expect { post workbench_collections_path, params: { collection: { name: "Mine" } } }.to change(Collection, :count).by(1)

      own = Collection.find_by!(name: "Mine")
      patch workbench_collection_path(own), params: { collection: { name: "Renamed" } }
      expect(own.reload.name).to eq("Renamed")

      expect { delete workbench_collection_path(own) }.to change(Collection, :count).by(-1)
    end
  end

  describe "folders and requests" do
    it "follows the collection for folders", :aggregate_failures do
      get new_workbench_collection_folder_path(collection)
      expect_forbidden

      expect { post workbench_collection_folders_path(collection), params: { folder: { name: "New" } } }.not_to change(Folder, :count)
      patch workbench_folder_path(folder), params: { folder: { name: "Renamed" } }
      expect_forbidden

      expect { delete workbench_folder_path(folder) }.not_to change(Folder, :count)
      patch workbench_folder_position_path(folder), params: { parent_id: "" }
      expect_forbidden
    end

    it "follows the collection for requests", :aggregate_failures do
      get new_workbench_collection_request_path(collection)
      expect_forbidden

      expect { post workbench_collection_requests_path(collection), params: { api_request: { name: "New" } } }.not_to change(ApiRequest, :count)
      patch workbench_request_path(api_request), params: { api_request: { name: "Renamed" } }
      expect_forbidden

      expect { delete workbench_request_path(api_request) }.not_to change(ApiRequest, :count)
      expect(api_request.reload.name).not_to eq("Renamed")
    end

    it "keeps members from duplicating, moving or configuring requests", :aggregate_failures do
      expect { post workbench_request_duplication_path(api_request) }.not_to change(ApiRequest, :count)
      expect_forbidden

      patch workbench_request_position_path(api_request), params: { collection_id: collection.id }
      expect_forbidden

      patch workbench_request_settings_path(api_request), params: { api_request: { settings: { timeout: 5 } } }
      expect_forbidden
    end

    it "keeps members from importing a cURL command into it" do
      post workbench_collection_curl_import_path(collection), params: { command: "curl https://example.com" }

      expect_forbidden
    end

    it "lets members read requests" do
      get workbench_request_path(api_request)

      expect(response).to have_http_status(:ok)
    end

    it "lets members manage the requests of a collection they created", :aggregate_failures do
      own = create(:collection, project:, creator: member)
      own_request = create(:api_request, collection: own)

      patch workbench_request_path(own_request), params: { api_request: { name: "Mine" } }
      expect(own_request.reload.name).to eq("Mine")

      expect { post workbench_request_duplication_path(own_request) }.to change(ApiRequest, :count).by(1)
    end

    it "keeps members from placing a draft into a collection they cannot change", :aggregate_failures do
      draft = create(:api_request, project:, collection: nil, user: member)

      patch workbench_request_placement_path(draft), params: { destination: "collection:#{collection.id}" }

      expect_forbidden
      expect(draft.reload.collection_id).to be_nil
    end

    it "keeps members from dropping a request into a collection they cannot change" do
      own = create(:collection, project:, creator: member)
      own_request = create(:api_request, collection: own)

      patch workbench_request_position_path(own_request), params: { collection_id: collection.id }

      expect_forbidden
    end
  end

  describe "running requests" do
    let(:url) { "https://api.example.com/items" }

    before { allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new) }

    it "sends the saved request without saving the member's edits", :aggregate_failures do
      stub_request(:get, url).to_return(status: 200, body: "ok")

      post workbench_request_executions_path(api_request), params: { api_request: { http_method: "DELETE", url: "https://evil.example.com" } }, headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(api_request.reload.http_method).to eq("GET")
      expect(a_request(:get, url)).to have_been_made
    end

    it "saves the edits of a member that may change the request", :aggregate_failures do
      own = create(:collection, project:, creator: member)
      own_request = create(:api_request, collection: own)
      stub_request(:post, url).to_return(status: 201, body: "created")

      post workbench_request_executions_path(own_request), params: { api_request: { http_method: "POST", url: } }, headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(own_request.reload.http_method).to eq("POST")
    end
  end

  describe "OAuth 2.0 tokens" do
    it "keeps members from storing a token on a request they cannot change", :aggregate_failures do
      api_request.update!(auth_type: "oauth2")

      post workbench_oauth2_token_path, params: { owner_type: "ApiRequest", owner_id: api_request.id }
      expect_forbidden

      delete workbench_oauth2_token_path, params: { owner_type: "ApiRequest", owner_id: api_request.id }
      expect_forbidden
    end

    it "keeps members from starting an authorization for it" do
      api_request.update!(auth_type: "oauth2")

      post workbench_oauth2_authorization_path, params: { owner_type: "ApiRequest", owner_id: api_request.id }

      expect_forbidden
    end
  end

  describe "environments" do
    it "keeps members from changing or deleting an environment they did not create", :aggregate_failures do
      get edit_environment_path(environment), headers: { "Turbo-Frame" => "right_sidebar" }
      expect_forbidden

      patch environment_path(environment), params: { environment: { name: "Hacked" } }
      expect_forbidden

      expect { delete environment_path(environment) }.not_to change(Environment, :count)
      expect_forbidden
    end

    it "lets members create environments and manage the ones they created", :aggregate_failures do
      expect { post environments_path, params: { environment: { name: "Mine" } } }.to change(Environment, :count).by(1)

      own = Environment.find_by!(name: "Mine")
      patch environment_path(own), params: { environment: { name: "Renamed" } }
      expect(own.reload.name).to eq("Renamed")

      expect { delete environment_path(own) }.to change(Environment, :count).by(-1)
    end

    it "answers background variable edits with a bare 403", :aggregate_failures do
      variable = create(:variable, environment:)

      post environment_variables_path(environment), params: { variable: { key: "TOKEN", value: "x" } }, headers: json_headers
      expect(response).to have_http_status(:forbidden)

      patch environment_variable_path(environment, variable), params: { variable: { value: "x" } }, headers: json_headers
      expect(response).to have_http_status(:forbidden)
    end

    it "lets members edit the variables of an environment they created", :aggregate_failures do
      own = create(:environment, project:, creator: member)
      variable = create(:variable, environment: own)

      post environment_variables_path(own), params: { variable: { key: "TOKEN", value: "x" } }, headers: json_headers
      expect(response).to have_http_status(:created)

      patch environment_variable_path(own, variable), params: { variable: { value: "y" } }, headers: json_headers
      expect(response).to have_http_status(:ok)
    end
  end

  describe "shared project data" do
    it "lets members use cookies, the cookie jar, imports and drafts", :aggregate_failures do
      delete cookie_jar_path
      expect(response).to redirect_to(cookies_path)

      post workbench_drafts_path
      expect(response).to have_http_status(:see_other)

      get new_workbench_import_path
      expect(response).to have_http_status(:ok)
    end
  end
end
