require "rails_helper"

RSpec.describe ThemeSwitcher::Component, type: :component do
  it "marks the system theme by default", :aggregate_failures do
    render_inline(described_class.new)

    expect(page).to have_css("button[aria-current=true].bg-solid", count: 1)
    expect(page).to have_css("button.text-body:not([aria-current])", count: 2)
  end

  it "marks the theme from the cookie" do
    vc_test_controller.request.cookies[:theme] = "dark"
    render_inline(described_class.new)

    expect(page).to have_css("button[aria-current=true][aria-label='#{I18n.t("components.theme_switcher.dark")}']")
  end
end
