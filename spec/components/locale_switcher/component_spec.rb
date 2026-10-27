require "rails_helper"

RSpec.describe LocaleSwitcher::Component, type: :component do
  it "renders a button per locale and highlights the current one", :aggregate_failures do
    I18n.with_locale(:es) { render_inline(described_class.new) }

    expect(page).to have_css("button[lang=es][aria-current=true].bg-solid", text: "ES")
    expect(page).to have_css("button[lang=en].text-body:not([aria-current])", text: "EN")
  end

  it "offers every available locale with its native name", :aggregate_failures do
    render_inline(described_class.new)

    expect(page).to have_css("button[lang]", count: I18n.available_locales.size)
    expect(page).to have_css("button[lang=zh-CN][aria-label=中文]", text: "ZH")
    expect(page).to have_css("button[lang=pt-BR][aria-label=Português]", text: "PT")
  end

  it "renders a plain group by default" do
    render_inline(described_class.new)

    expect(page).to have_no_css("[data-controller~=disclosure]")
  end

  it "collapses behind a globe toggle when collapsible", :aggregate_failures do
    render_inline(described_class.new(collapsible: true))

    expect(page).to have_css("[data-controller~=disclosure] button[data-disclosure-target=trigger][aria-expanded=false] svg")
    expect(page).to have_css("[data-disclosure-target=panel][inert] button[lang]", count: I18n.available_locales.size, visible: :all)
  end
end
