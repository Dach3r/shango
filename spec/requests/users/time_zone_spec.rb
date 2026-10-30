require "rails_helper"

RSpec.describe "Time zone" do
  it "saves the zone from the profile tab", :aggregate_failures do
    user = sign_in_with_project.first

    put user_registration_path(tab: "profile"), params: { user: { first_name: user.first_name, last_name: user.last_name, email: user.email, time_zone: "Santiago" } }

    expect(response).to redirect_to(edit_user_registration_path(tab: "profile"))
    expect(user.reload.time_zone).to eq("Santiago")
  end

  it "rejects an unknown zone", :aggregate_failures do
    user = sign_in_with_project.first

    put user_registration_path(tab: "profile"), params: { user: { first_name: user.first_name, last_name: user.last_name, email: user.email, time_zone: "Mars/Olympus" } }

    expect(user.reload.time_zone).to eq("UTC")
  end

  it "offers the selector on the profile tab" do
    sign_in_with_project

    get edit_user_registration_path(tab: "profile")

    expect(response.body).to include(I18n.t("devise.registrations.edit.time_zone.label"))
  end

  it "shows monitor check times in the user's zone" do
    user, project = sign_in_with_project
    user.update!(time_zone: "Santiago")
    monitor = create(:uptime_monitor, project:)
    create(:check_result, uptime_monitor: monitor, checked_at: Time.utc(2026, 10, 30, 18, 3))

    get monitoring_monitor_path(monitor)

    expect(response.body).to include("15:03")
  end
end
