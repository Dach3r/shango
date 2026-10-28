require "rails_helper"

RSpec.describe NetworkRail::Component, type: :component do
  let(:items) do
    [{ name: "dns", label: "DNS", icon: "search", group: "Names", path: "/network" },
     { name: "ports", label: "Ports", icon: "radar", group: "Reach", path: "/network/ports" },
     { name: "ping", label: "Ping", icon: "activity", group: "Reach", path: "/network/ping" }]
  end

  it "renders one icon link per tool and marks the one on display", :aggregate_failures do
    render_inline(described_class.new(items:, current: "ping", label: "Network tools"))

    expect(page).to have_css("nav[aria-label='Network tools']")
    expect(page).to have_css("a[href='/network'][aria-label=DNS][title=DNS] svg")
    expect(page).to have_no_css("a[href='/network'][aria-current]")
    expect(page).to have_css("a[href='/network/ping'][aria-current=page]")
  end

  it "groups the tools and separates every group after the first", :aggregate_failures do
    render_inline(described_class.new(items:, current: "dns"))

    expect(page).to have_css("[role=group][aria-label=Names] a", count: 1)
    expect(page).to have_css("[role=group][aria-label=Reach] a", count: 2)
    expect(page).to have_no_css("[role=group][aria-label=Names].border-l")
    expect(page).to have_css("[role=group][aria-label=Reach].border-l")
  end
end
