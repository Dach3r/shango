require "rails_helper"

RSpec.describe "Throttling" do
  def limit(name, count)
    stub_const("ENV", ENV.to_h.merge("SHANGO_RATE_LIMIT_#{name.to_s.upcase}" => "#{count}/60"))
  end

  before { allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new) }

  describe Throttling do
    it "parses the environment override", :aggregate_failures do
      limit(:executions, 7)

      expect(described_class.limit(:executions)).to eq([7, 60.seconds])
    end

    it "ignores malformed overrides" do
      stub_const("ENV", ENV.to_h.merge("SHANGO_RATE_LIMIT_EXECUTIONS" => "lots"))

      expect(described_class.limit(:executions)).to eq(described_class::LIMITS[:executions])
    end

    it "uses the default without override" do
      expect(described_class.limit(:imports)).to eq([10, 10.minutes])
    end
  end

  describe "signed-out endpoints" do
    let(:credentials) { { user: { email: "nobody@example.com", password: "wrong" } } }

    it "limits sign in attempts per IP", :aggregate_failures do
      limit(:sign_in, 2)
      2.times { post user_session_path, params: credentials }
      post user_session_path, params: credentials

      expect(response).to redirect_to(new_user_session_path)
      expect(response.headers["Retry-After"]).to eq("60")
      expect(flash[:alert]).to eq(I18n.t("throttling.limited"))
    end

    it "limits sign ups per IP", :aggregate_failures do
      limit(:sign_up, 1)
      post user_registration_path, params: { user: { email: "" } }
      post user_registration_path, params: { user: { email: "" } }

      expect(response).to redirect_to(new_user_session_path)
    end

    it "limits password reset requests per IP", :aggregate_failures do
      limit(:password_reset, 1)
      post user_password_path, params: { user: { email: "nobody@example.com" } }
      post user_password_path, params: { user: { email: "nobody@example.com" } }

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "workbench endpoints" do
    include_context "with workbench project"

    let(:oauth_collection) do
      create(:collection, project:, auth_type: "oauth2",
                          auth_config: { "grant_type" => "client_credentials", "token_url" => "https://auth.example.com/token", "client_id" => "id", "client_secret" => "secret" })
    end

    it "limits executions per user and answers the response panel", :aggregate_failures do
      limit(:executions, 1)
      stub_request(:get, "https://api.example.com/items").to_return(status: 200)
      2.times { post workbench_request_executions_path(api_request), headers: turbo_headers }

      expect(response).to have_http_status(:too_many_requests)
      expect(response.body).to include("response_panel", I18n.t("throttling.limited"))
    end

    it "limits imports per user", :aggregate_failures do
      limit(:imports, 1)
      2.times { post workbench_import_path, params: { content: "" } }

      expect(response).to redirect_to(workbench_root_path)
      expect(flash[:alert]).to eq(I18n.t("throttling.limited"))
    end

    it "limits cURL imports per user" do
      limit(:imports, 1)
      2.times { post workbench_collection_curl_import_path(collection), params: { command: "" } }

      expect(response).to redirect_to(workbench_root_path)
    end

    it "limits OAuth token requests per user" do
      limit(:oauth, 1)
      stub_request(:post, "https://auth.example.com/token").to_return(status: 200, body: { access_token: "tok" }.to_json)
      2.times { post workbench_oauth2_token_path, params: { owner_type: "Collection", owner_id: oauth_collection.id } }

      expect(response).to redirect_to(workbench_root_path)
    end

    it "limits OAuth authorizations per user" do
      limit(:oauth, 1)
      2.times { post workbench_oauth2_authorization_path, params: { owner_type: "Collection", owner_id: oauth_collection.id } }

      expect(response).to redirect_to(workbench_root_path)
    end

    it "limits invitations per project", :aggregate_failures do
      limit(:invitations, 1)
      2.times { |index| post invitations_path, params: { invitation: { email: "new#{index}@example.com", role: "member" } } }

      expect(response).to redirect_to(workbench_root_path)
      expect(flash[:alert]).to eq(I18n.t("throttling.limited"))
      expect(Invitation.count).to eq(1)
    end

    it "does not count invitations of other projects", :aggregate_failures do
      limit(:invitations, 1)
      post invitations_path, params: { invitation: { email: "new@example.com", role: "member" } }
      sign_out user
      sign_in_with_project
      post invitations_path, params: { invitation: { email: "other@example.com", role: "member" } }

      expect(Invitation.count).to eq(2)
    end

    it "limits attempts at invitation tokens per user", :aggregate_failures do
      limit(:invitation_acceptance, 2)
      3.times { get invitation_acceptance_path(token: "guess") }

      expect(response).to redirect_to(workbench_root_path)
      expect(flash[:alert]).to eq(I18n.t("throttling.limited"))
    end

    it "counts each user separately", :aggregate_failures do
      limit(:imports, 1)
      post workbench_import_path, params: { content: "" }
      sign_out user
      sign_in_with_project
      post workbench_import_path, params: { content: "" }

      expect(flash[:alert]).to be_blank
    end
  end

  describe "windows and actors" do
    include ActiveSupport::Testing::TimeHelpers

    let(:credentials) { { user: { email: "nobody@example.com", password: "wrong" } } }

    it "lets the exact limit through and blocks the next attempt", :aggregate_failures do
      limit(:sign_in, 3)
      3.times { post user_session_path, params: credentials }
      expect(response).not_to redirect_to(new_user_session_path)

      post user_session_path, params: credentials
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to eq(I18n.t("throttling.limited"))
    end

    it "counts each IP separately", :aggregate_failures do
      limit(:sign_in, 1)
      2.times { post user_session_path, params: credentials, headers: { "REMOTE_ADDR" => "10.0.0.1" } }
      expect(response).to redirect_to(new_user_session_path)

      post user_session_path, params: credentials, headers: { "REMOTE_ADDR" => "10.0.0.2" }
      expect(response).not_to redirect_to(new_user_session_path)
    end

    it "lets requests through again after the window", :aggregate_failures do
      limit(:sign_in, 1)
      2.times { post user_session_path, params: credentials }
      expect(response).to redirect_to(new_user_session_path)

      travel_to(61.seconds.from_now) { post user_session_path, params: credentials }
      expect(response).not_to redirect_to(new_user_session_path)
    end

    it "keeps limits independent of each other", :aggregate_failures do
      limit(:sign_in, 1)
      2.times { post user_session_path, params: credentials }
      post user_password_path, params: { user: { email: "nobody@example.com" } }

      expect(flash[:alert]).not_to eq(I18n.t("throttling.limited"))
    end

    it "does not create an account once the sign up limit is reached", :aggregate_failures do
      limit(:sign_up, 1)
      params = { user: { first_name: "A", last_name: "B", password: "password123", password_confirmation: "password123" } }
      post user_registration_path, params: params.deep_merge(user: { email: "one@example.com" })

      expect { post user_registration_path, params: params.deep_merge(user: { email: "two@example.com" }) }.not_to change(User, :count)
    end

    it "treats a zero or non numeric override as the default or a hard block", :aggregate_failures do
      stub_const("ENV", ENV.to_h.merge("SHANGO_RATE_LIMIT_SIGN_IN" => "5/abc"))
      expect(Throttling.limit(:sign_in)).to eq([10, 1.minute])

      stub_const("ENV", ENV.to_h.merge("SHANGO_RATE_LIMIT_SIGN_IN" => "0/60"))
      post user_session_path, params: credentials
      expect(response).to redirect_to(new_user_session_path)
    end

    it "falls back to the workbench for signed-in users", :aggregate_failures do
      limit(:imports, 1)
      sign_in_with_project
      2.times { post workbench_import_path, params: { content: "" } }

      expect(response).to redirect_to(workbench_root_path)
    end

    it "does not block when the cache cannot count" do
      limit(:sign_in, 1)
      allow(Rails.cache).to receive(:increment).and_return(nil)
      3.times { post user_session_path, params: credentials }

      expect(response).not_to redirect_to(new_user_session_path)
    end
  end
end
