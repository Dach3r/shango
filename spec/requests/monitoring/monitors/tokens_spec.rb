require "rails_helper"

RSpec.describe "Monitoring push tokens" do
  let(:context) { sign_in_with_project }
  let(:project) { context[1] }
  let(:monitor) { create(:uptime_monitor, :push, project:, creator: context[0]) }

  before { context }

  it "creates a new push URL and shows it once", :aggregate_failures do
    old = monitor.push_token_digest
    post monitoring_monitor_token_path(monitor)

    expect(response).to redirect_to(monitoring_monitor_path(monitor))
    expect(monitor.reload.push_token_digest).not_to eq(old)
    follow_redirect!
    expect(response.body).to include(I18n.t("monitoring.push.once"), "X-Shango-Push-Token")
    get monitoring_monitor_path(monitor)
    expect(response.body).to include(I18n.t("monitoring.push.hidden"))
    expect(response.body).not_to include(I18n.t("monitoring.push.once"))
  end

  it "has no token for other kinds" do
    post monitoring_monitor_token_path(create(:uptime_monitor, project:))

    expect(response).to have_http_status(:not_found)
  end
end
