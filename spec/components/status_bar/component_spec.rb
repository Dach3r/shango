require "rails_helper"

RSpec.describe StatusBar::Component, type: :component do
  it "renders the menu button without environments", :aggregate_failures do
    render_inline(described_class.new)

    expect(page).to have_css("footer button[data-action='drawer#toggle']")
    expect(page).to have_no_css("button", text: I18n.t("components.environment_switcher.none"))
  end

  it "renders the environment switcher when environments are given" do
    render_inline(described_class.new(environments: [], current_environment: nil))

    expect(page).to have_css("button", text: I18n.t("components.environment_switcher.none"))
  end

  it "renders the given content" do
    render_inline(described_class.new) { "Breadcrumb" }

    expect(page).to have_css("footer", text: "Breadcrumb")
  end

  it "wires the sidebar toggle to the current state", :aggregate_failures do
    render_inline(described_class.new)
    expect(page).to have_css("button[data-action='sidebar#toggle'][aria-expanded=true]", visible: :all)

    render_inline(described_class.new(collapsed: true))
    expect(page).to have_css("button[data-action='sidebar#toggle'][aria-expanded=false]", visible: :all)
  end
end
