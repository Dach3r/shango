require "rails_helper"

RSpec.describe NetworkRail::Component, type: :component do
  let(:items) { [{ name: "dns", label: "DNS", icon: "search" }, { name: "ping", label: "Ping", icon: "activity" }] }

  it "renders one icon tab per tool wired to the tabs controller", :aggregate_failures do
    render_inline(described_class.new(items:, label: "Network tools"))

    expect(page).to have_css("[role=tablist][aria-label='Network tools']")
    expect(page).to have_css("button[role=tab][data-name=dns][aria-label=DNS][title=DNS][data-action='tabs#select'] svg")
    expect(page).to have_css("button[role=tab][data-name=ping][data-tabs-name-param=ping]")
  end
end
