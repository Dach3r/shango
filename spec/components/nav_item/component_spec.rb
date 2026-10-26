require "rails_helper"

RSpec.describe NavItem::Component, type: :component do
  it "renders an active link", :aggregate_failures do
    render_inline(described_class.new(label: "Home", icon: "home", href: "/", active: true))

    expect(page).to have_css("a[href='/'][aria-current=page].text-accent", text: "Home")
  end

  it "renders an inactive link" do
    render_inline(described_class.new(label: "Home", icon: "home", href: "/"))

    expect(page).to have_css("a.text-body:not([aria-current])")
  end

  it "renders a disabled entry flagged as soon", :aggregate_failures do
    render_inline(described_class.new(label: "Logs", icon: "scroll-text"))

    expect(page).to have_css("span[aria-disabled=true].cursor-not-allowed", text: "Logs")
    expect(page).to have_css("span[title$='#{I18n.t("components.nav_item.soon")}']")
  end

  it "hides the label when the sidebar is collapsed", :aggregate_failures do
    render_inline(described_class.new(label: "Home", icon: "home", href: "/"))

    expect(page.native.to_html).to include("group-data-[collapsed=true]/sidebar:hidden")
    expect(page.native.to_html).to include("group-data-[collapsed=true]/sidebar:size-10")
  end

  it "keeps the label visible when not collapsible", :aggregate_failures do
    render_inline(described_class.new(label: "Home", icon: "home", href: "/", collapsible: false))

    expect(page.native.to_html).not_to include("group-data-[collapsed=true]/sidebar")
  end
end
