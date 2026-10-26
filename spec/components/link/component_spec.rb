require "rails_helper"

RSpec.describe Link::Component, type: :component do
  it "renders an accent link with extra classes" do
    render_inline(described_class.new(label: "Home", href: "/", class: "extra"))

    expect(page).to have_link("Home", href: "/", class: %w[text-accent extra])
  end
end
