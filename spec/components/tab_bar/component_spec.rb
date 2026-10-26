require "rails_helper"

RSpec.describe TabBar::Component, type: :component do
  let(:items) do
    [
      { name: "params", label: "Params", count: 2 },
      { name: "auth", label: "Auth", dot: true },
      { name: "docs", label: "Docs", disabled: true },
      { name: "plain", label: "Plain", count: 0 }
    ]
  end

  it "renders tabs with counts, dots and disabled badges", :aggregate_failures do
    render_inline(described_class.new(items:, label: "Request"))

    expect(page).to have_css("[role=tablist][aria-label=Request]")
    expect(page).to have_css("button[data-name=params] span", text: "2")
    expect(page).to have_css("button[data-name=auth] span[aria-hidden=true]")
    expect(page).to have_css("button[data-name=docs][disabled]", text: I18n.t("components.nav_item.soon"))
    expect(page).to have_no_css("button[data-name=plain] span")
  end
end
