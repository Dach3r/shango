require "rails_helper"

RSpec.describe "Theme settings", :system do
  let(:user) { create(:user) }
  let(:membership) { create(:membership, :owner, user:) }

  before do
    user.update!(current_membership: membership)
    login_as user, scope: :user
  end

  it "keeps the theme tab open after picking a theme" do
    visit edit_theme_path
    click_button "Styles"
    find("label", text: "Ocean").click

    expect(page).to have_css("html[data-palette='ocean']")
    expect(page).to have_css("[role='tab'][aria-selected='true']", text: "Styles")
    expect(page).to have_css("label", text: "Ocean", visible: :visible)
  end
end
