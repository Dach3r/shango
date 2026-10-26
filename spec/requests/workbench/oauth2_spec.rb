require "rails_helper"

RSpec.describe "Workbench OAuth2" do
  include_context "with workbench project"

  let(:token_url) { "https://auth.example.com/token" }
  let(:oauth_config) do
    { "grant_type" => "client_credentials", "token_url" => token_url, "client_id" => "id", "client_secret" => "secret" }
  end
  let(:oauth_collection) { create(:collection, project:, auth_type: "oauth2", auth_config: oauth_config) }
  let(:code_collection) do
    create(:collection, project:, auth_type: "oauth2",
                        auth_config: oauth_config.merge("grant_type" => "authorization_code", "authorization_url" => "https://auth.example.com/authorize"))
  end
  let(:owner_params) { { owner_type: "Collection", owner_id: oauth_collection.id } }

  describe "POST /workbench/oauth2/token" do
    it "fetches and stores a token", :aggregate_failures do
      stub_request(:post, token_url).to_return(status: 200, body: { access_token: "tok", expires_in: 60 }.to_json)
      post workbench_oauth2_token_path, params: owner_params, headers: { "HTTP_REFERER" => "http://www.example.com/workbench" }

      expect(response).to redirect_to("http://www.example.com/workbench")
      expect(flash[:notice]).to be_present
      expect(oauth_collection.reload.auth_config["access_token"]).to eq("tok")
    end

    it "reports failures", :aggregate_failures do
      stub_request(:post, token_url).to_return(status: 400, body: { error: "invalid_client" }.to_json)
      post workbench_oauth2_token_path, params: owner_params

      expect(response).to redirect_to(workbench_root_path)
      expect(flash[:alert]).to include("invalid_client")
    end

    it "rejects unknown owner types" do
      post workbench_oauth2_token_path, params: { owner_type: "User", owner_id: user.id }

      expect(response).to have_http_status(:not_found)
    end

    it "rejects owners of other projects" do
      other = create(:collection, auth_type: "oauth2", auth_config: oauth_config)
      post workbench_oauth2_token_path, params: { owner_type: "Collection", owner_id: other.id }

      expect(response).to have_http_status(:not_found)
    end

    it "rejects owners without oauth2 auth" do
      post workbench_oauth2_token_path, params: { owner_type: "Collection", owner_id: collection.id }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /workbench/oauth2/token" do
    it "clears stored tokens", :aggregate_failures do
      oauth_collection.update!(auth_config: oauth_config.merge("access_token" => "tok"))
      delete workbench_oauth2_token_path, params: owner_params

      expect(response).to redirect_to(workbench_root_path)
      expect(oauth_collection.reload.auth_config).not_to have_key("access_token")
    end
  end

  describe "POST /workbench/oauth2/authorization" do
    it "redirects to the provider and remembers the flow", :aggregate_failures do
      post workbench_oauth2_authorization_path, params: { owner_type: "Collection", owner_id: code_collection.id }, headers: { "HTTP_REFERER" => "http://www.example.com/workbench/requests/1" }

      expect(response.location).to start_with("https://auth.example.com/authorize?")
      expect(response.location).to include("code_challenge_method=S256")
    end

    it "falls back to the workbench root without a referer", :aggregate_failures do
      post workbench_oauth2_authorization_path, params: { owner_type: "Collection", owner_id: code_collection.id }

      expect(response.location).to start_with("https://auth.example.com/authorize?")
    end

    it "fails without an authorization url", :aggregate_failures do
      post workbench_oauth2_authorization_path, params: owner_params

      expect(response).to redirect_to(workbench_root_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe "GET /workbench/oauth2/callback" do
    def start_flow(referer: "http://www.example.com/workbench/requests/1")
      post workbench_oauth2_authorization_path, params: { owner_type: "Collection", owner_id: code_collection.id }, headers: { "HTTP_REFERER" => referer }
      Rack::Utils.parse_query(URI.parse(response.location).query)["state"]
    end

    it "exchanges the code and returns to the origin", :aggregate_failures do
      stub_request(:post, token_url).to_return(status: 200, body: { access_token: "tok" }.to_json)
      state = start_flow
      get workbench_oauth2_callback_path, params: { code: "abc", state: }

      expect(response).to redirect_to("http://www.example.com/workbench/requests/1")
      expect(flash[:notice]).to be_present
      expect(code_collection.reload.auth_config["access_token"]).to eq("tok")
    end

    it "reports exchange failures", :aggregate_failures do
      stub_request(:post, token_url).to_return(status: 400, body: { error: "invalid_grant" }.to_json)
      state = start_flow
      get workbench_oauth2_callback_path, params: { code: "abc", state: }

      expect(flash[:alert]).to include("invalid_grant")
    end

    it "falls back to the root when the origin is blank", :aggregate_failures do
      stub_request(:post, token_url).to_return(status: 200, body: { access_token: "tok" }.to_json)
      state = start_flow(referer: "")
      get workbench_oauth2_callback_path, params: { code: "abc", state: }

      expect(response).to redirect_to(workbench_root_path)
    end

    it "rejects a mismatching state", :aggregate_failures do
      start_flow
      get workbench_oauth2_callback_path, params: { code: "abc", state: "forged" }

      expect(response).to redirect_to(workbench_root_path)
      expect(flash[:alert]).to be_present
    end

    it "rejects callbacks without a stored flow" do
      get workbench_oauth2_callback_path, params: { code: "abc", state: "x" }

      expect(flash[:alert]).to be_present
    end

    it "rejects callbacks without a code" do
      state = start_flow
      get workbench_oauth2_callback_path, params: { state: }

      expect(flash[:alert]).to be_present
    end
  end
end
