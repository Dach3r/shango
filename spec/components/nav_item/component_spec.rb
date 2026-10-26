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
    expect(page).to have_no_css("span.max-lg\\:sr-only")
  end

  it "lines up in a bar and hides the label on small screens", :aggregate_failures do
    render_inline(described_class.new(label: "Home", icon: "home", href: "/", active: true, orientation: :horizontal))

    expect(page).to have_css("a.border-r.shadow-\\[inset_0_-2px_0_var\\(--accent\\)\\]")
    expect(page).to have_css("span.max-lg\\:sr-only", text: "Home")
  end
end
