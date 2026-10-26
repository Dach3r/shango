require "rails_helper"

RSpec.describe ZoomPicker::Component, type: :component do
  before { vc_test_controller.request.cookies[:zoom] = "125" }

  it "renders a radio per level, checks the current one and marks the default", :aggregate_failures do
    I18n.with_locale(:es) { render_inline(described_class.new) }

    expect(page).to have_css("input[type=radio][name=zoom]", count: Zooming::LEVELS.size)
    expect(page).to have_css("input[value='125'][checked]")
    expect(page).to have_css("span.font-semibold", text: "100%")
    expect(page).to have_text("Predeterminado", count: 1)
  end
end
