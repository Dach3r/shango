require "rails_helper"

RSpec.describe UserMenu::Component, type: :component do
  it "renders user details, switchers and sign out", :aggregate_failures do
    user = create(:user, first_name: "Ada", last_name: "Lovelace", email: "ada@example.com")
    render_inline(described_class.new(user:))

    expect(page.text(:all)).to include("Ada Lovelace")
    expect(page.text(:all)).to include("ada@example.com")
    expect(page).to have_link(I18n.t("components.user_menu.settings"), href: "/membership/settings", visible: :all)
    expect(page).to have_button(I18n.t("components.user_menu.sign_out"), visible: :all)
    expect(page).to have_css("[data-controller=theme-switcher]", visible: :all)
    expect(page).to have_css("[data-controller=dropdown] button[aria-haspopup=true]", visible: :all)
  end
end
