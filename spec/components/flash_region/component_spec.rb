require "rails_helper"

RSpec.describe FlashRegion::Component, type: :component do
  it "renders string flash messages as flash messages", :aggregate_failures do
    flash = ActionDispatch::Flash::FlashHash.new("notice" => "Saved", "alert" => "Oops", "blank" => "", "other" => 1)
    render_inline(described_class.new(flash:))

    expect(page).to have_css("#flash[aria-live=polite]")
    expect(page).to have_css("[role=status]", text: "Saved")
    expect(page).to have_css("[role=alert]", text: "Oops")
    expect(page).to have_css("[data-controller=flash]", count: 2)
  end
end
