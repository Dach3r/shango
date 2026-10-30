require "rails_helper"

RSpec.describe "Monitor form", :system do
  let(:user) { create(:user) }
  let(:membership) { create(:membership, :owner, user:) }

  before do
    user.update!(current_membership: membership)
    login_as user, scope: :user
  end

  it "creates an HTTP monitor with the selects and switches the target to a saved request", :aggregate_failures do
    visit new_monitoring_monitor_path(kind: "http")
    fill_in UptimeMonitor.human_attribute_name(:name), with: "Shop"
    fill_in UptimeMonitor.human_attribute_name(:url), with: "https://shop.example.com/health"
    find_by_id("uptime_monitor_settings_http_method").click
    find("button[role=option]", text: "HEAD").click
    find_by_id("uptime_monitor_settings_mode").click
    find("button[role=option]", text: I18n.t("monitoring.form.modes.request")).click

    expect(page).to have_no_field(UptimeMonitor.human_attribute_name(:url))
    expect(page).to have_text(I18n.t("monitoring.form.request_hint"))

    find_by_id("uptime_monitor_settings_mode").click
    find("button[role=option]", text: I18n.t("monitoring.form.modes.url")).click
    click_button I18n.t("monitoring.form.create")

    expect(page).to have_text(I18n.t("monitoring.monitors.create.created"))
    expect(membership.project.uptime_monitors.last).to have_attributes(name: "Shop", url: "https://shop.example.com/health", http_method: "HEAD", mode: "url")
  end
end
