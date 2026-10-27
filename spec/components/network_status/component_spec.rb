require "rails_helper"

RSpec.describe NetworkStatus::Component, type: :component do
  it "renders the localized status with its tone", :aggregate_failures do
    render_inline(described_class.new(status: :open))

    expect(page).to have_css("span.text-emerald-700", text: I18n.t("network.statuses.open"))
  end

  it "has a label and a tone for every status", :aggregate_failures do
    described_class::STATUS_TONES.each_key do |status|
      render_inline(described_class.new(status:))

      expect(page).to have_css("span", text: I18n.t("network.statuses.#{status}")), status.to_s
    end
  end

  it "accepts the status as a string" do
    render_inline(described_class.new(status: "timeout"))

    expect(page).to have_text(I18n.t("network.statuses.timeout"))
  end
end
