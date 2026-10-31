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
end
