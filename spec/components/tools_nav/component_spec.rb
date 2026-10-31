require "rails_helper"

RSpec.describe ToolsNav::Component, type: :component do
  it "links built tools and disables the rest", :aggregate_failures do
    render_inline(described_class.new)

    expect(page).to have_link(I18n.t("components.tools_nav.overview"), href: "/overview")
    expect(page).to have_link(I18n.t("components.tools_nav.api_client"), href: "/workbench")
    expect(page).to have_link(I18n.t("components.tools_nav.network"), href: "/network")
    expect(page).to have_link(I18n.t("components.tools_nav.monitoring"), href: "/monitoring")
    expect(page).to have_css("span[aria-disabled=true]", text: I18n.t("components.tools_nav.logs"))
  end

  it "flags the open incidents on Monitoring only", :aggregate_failures do
    render_inline(described_class.new(open_incidents: 4))

    expect(page).to have_css("a[href='/monitoring'] span", text: "4")
    expect(page).to have_no_css("a[href='/workbench'] span.font-mono")
  end

  it "flags nothing without open incidents" do
    render_inline(described_class.new)

    expect(page).to have_no_css("a[href='/monitoring'] span.font-mono")
  end
end
