require "rails_helper"

RSpec.describe NetworkRail::Component, type: :component do
  let(:items) { [{ name: "dns", label: "DNS", icon: "search", path: "/network" }, { name: "ping", label: "Ping", icon: "activity", path: "/network/ping" }] }

  it "renders one icon link per tool and marks the one on display", :aggregate_failures do
    render_inline(described_class.new(items:, current: "ping", label: "Network tools"))

    expect(page).to have_css("nav[aria-label='Network tools']")
    expect(page).to have_css("a[href='/network'][aria-label=DNS][title=DNS] svg")
    expect(page).to have_no_css("a[href='/network'][aria-current]")
    expect(page).to have_css("a[href='/network/ping'][aria-current=page]")
  end
end
