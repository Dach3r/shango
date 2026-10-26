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

  it "stacks vertically by default", :aggregate_failures do
    render_inline(described_class.new(label: "Home", icon: "home", href: "/", active: true))

    expect(page).to have_css("a.border-b.shadow-\\[inset_2px_0_0_var\\(--accent\\)\\]")
  end

  it "lists upcoming entries in a menu with a soon badge", :aggregate_failures do
    render_inline(described_class.new(label: "Logs", icon: "scroll-text", orientation: :menu))

    expect(page).to have_css("span[aria-disabled=true].w-full", text: "Logs")
    expect(page).to have_css("span", text: I18n.t("components.nav_item.soon"))
  end
end
