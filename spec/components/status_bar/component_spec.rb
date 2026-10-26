require "rails_helper"

RSpec.describe StatusBar::Component, type: :component do
  it "renders without environments" do
    render_inline(described_class.new)

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

  it "renders the sidebar toggle only when requested" do
    render_inline(described_class.new)
    expect(page).to have_no_css("button[data-action='sidebar-toggle#toggle']")

    render_inline(described_class.new(sidebar_toggle: true))
    expect(page).to have_css("button[data-action='sidebar-toggle#toggle'][aria-expanded='true']")
  end
end
