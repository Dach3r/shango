require "rails_helper"

RSpec.describe MonitorStatus::Component, type: :component do
  it "has a label and a tone for every status", :aggregate_failures do
    described_class::TONES.each_key do |status|
      render_inline(described_class.new(status:))

      expect(page).to have_css("span", text: I18n.t("monitoring.statuses.#{status}")), status.to_s
    end
  end

  it "shows a disabled monitor as paused and otherwise its status", :aggregate_failures do
    render_inline(described_class.for(build(:uptime_monitor, enabled: false)))

    expect(page).to have_text(I18n.t("monitoring.statuses.paused"))

    render_inline(described_class.for(build(:uptime_monitor)))

    expect(page).to have_text(I18n.t("monitoring.statuses.pending"))
  end
end
