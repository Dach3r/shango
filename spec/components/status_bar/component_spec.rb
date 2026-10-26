require "rails_helper"

RSpec.describe StatusBar::Component, type: :component do
  let(:user) { create(:user, first_name: "Ada", last_name: "Lovelace") }

  it "renders the user menu without environments", :aggregate_failures do
    render_inline(described_class.new(user:))

    expect(page).to have_css("footer button", text: "AL")
    expect(page).to have_no_css("button", text: I18n.t("components.environment_switcher.none"))
  end

  it "renders the environment switcher when environments are given" do
    render_inline(described_class.new(user:, environments: [], current_environment: nil))

    expect(page).to have_css("button", text: I18n.t("components.environment_switcher.none"))
  end
end
