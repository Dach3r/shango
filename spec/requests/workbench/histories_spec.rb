require "rails_helper"

RSpec.describe "Workbench history" do
  include_context "with workbench project"

  it "requires sign in" do
    sign_out user
    get workbench_history_path

    expect(response).to redirect_to(new_user_session_path)
  end

  it "shows the empty state" do
    get workbench_history_path

    expect(response.body).to include(I18n.t("workbench.histories.show.empty_title"))
  end

  it "lists the user's executions grouped by collection", :aggregate_failures do
    environment = create(:environment, project:)
    create(:request_execution, api_request:, user:, environment:, url: "https://api.example.com/mine", duration_ms: 120)
    create(:request_execution, api_request:, user:, url: "https://api.example.com/plain")
    draft = create(:api_request, project:, collection: nil, user:, name: "Scratch")
    create(:request_execution, api_request: draft, user:)
    create(:request_execution, api_request:, user: create(:user), url: "https://api.example.com/theirs")
    get workbench_history_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(collection.name, "https://api.example.com/mine", environment.name, "Scratch", I18n.t("workbench.histories.show.drafts"), I18n.t("workbench.histories.show.no_environment"))
    expect(response.body).not_to include("https://api.example.com/theirs")
  end
end
