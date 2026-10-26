require "rails_helper"

RSpec.describe LocaleSwitcher::Component, type: :component do
  it "renders a button per locale and highlights the current one", :aggregate_failures do
    I18n.with_locale(:es) { render_inline(described_class.new) }

    expect(page).to have_css("button[lang=es][aria-current=true].bg-solid", text: "ES")
    expect(page).to have_css("button[lang=en].text-body:not([aria-current])", text: "EN")
  end
end
