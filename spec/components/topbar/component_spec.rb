require "rails_helper"

RSpec.describe Topbar::Component, type: :component do
  let(:user) { create(:user, first_name: "Ada", last_name: "Lovelace") }

  it "renders the title and user menu without environments", :aggregate_failures do
    render_inline(described_class.new(user:, title: "Overview"))

    expect(page).to have_css("h1", text: "Overview")
    expect(page).to have_css("button", text: "AL")
    expect(page).to have_no_css("button", text: I18n.t("components.environment_switcher.none"))
  end

  it "renders the environment switcher when environments are given" do
    render_inline(described_class.new(user:, environments: [], current_environment: nil))

    expect(page).to have_css("button", text: I18n.t("components.environment_switcher.none"))
  end
end
