require "rails_helper"

RSpec.describe UserMenu::Component, type: :component do
  it "links the initials avatar to the account side panel", :aggregate_failures do
    user = create(:user, first_name: "Ada", last_name: "Lovelace")
    render_inline(described_class.new(user:))

    expect(page).to have_css("a[href='/account'][data-turbo-frame=right_sidebar][data-action='right-sidebar#toggle']", text: "AL")
    expect(page).to have_css("a[title='Ada Lovelace']")
  end
end
