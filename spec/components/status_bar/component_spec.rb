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
end
