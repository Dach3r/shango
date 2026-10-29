require "rails_helper"

RSpec.describe "Monitoring monitor pauses" do
  let(:context) { sign_in_with_project }
  let(:project) { context[1] }
  let(:monitor) { create(:uptime_monitor, project:) }

  before { context }

  it "pauses and resumes a monitor", :aggregate_failures do
    post monitoring_monitor_pause_path(monitor)

    expect(response).to redirect_to(monitoring_monitor_path(monitor))
    expect(monitor.reload).to be_paused

    delete monitoring_monitor_pause_path(monitor), headers: { "Referer" => monitoring_root_url }

    expect(response).to redirect_to(monitoring_root_url)
    expect(monitor.reload).to have_attributes(enabled: true, status: "pending")
  end
end
