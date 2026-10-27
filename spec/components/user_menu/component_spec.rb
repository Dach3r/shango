require "rails_helper"

RSpec.describe UserMenu::Component, type: :component do
  it "links a menu button to the account side panel", :aggregate_failures do
    user = create(:user, first_name: "Ada", last_name: "Lovelace")
    render_inline(described_class.new(user:))

    expect(page).to have_css("a[href='/account'][data-turbo-frame=right_sidebar][data-action='right-sidebar#toggle']", text: "Menu")
    expect(page).to have_css("a[title='Ada Lovelace'] svg")
  end
end
