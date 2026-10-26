require "rails_helper"

RSpec.describe Logo::Component, type: :component do
  it "renders the bolt and the app name in a link", :aggregate_failures do
    render_inline(described_class.new(href: "/", class: "extra"))

    expect(page).to have_css("a.extra[href='/'] svg", visible: :all)
    expect(page).to have_text(ApplicationHelper::CONFIG[:name])
  end
end
