require "rails_helper"

RSpec.describe Flash::Component, type: :component do
  it "renders a notice by default", :aggregate_failures do
    render_inline(described_class.new(message: "Saved", class: "extra"))

    expect(page).to have_css("div[role=status][data-flash-delay-value='5000'].border-solid.extra", text: "Saved")
  end

  it "renders alerts with a longer delay", :aggregate_failures do
    render_inline(described_class.new(message: "Oops", kind: "alert"))

    expect(page).to have_css("div[role=alert][data-flash-delay-value='8000'].border-danger")
  end

  it "falls back to notice for unknown kinds" do
    render_inline(described_class.new(message: "Hi", kind: :other))

    expect(page).to have_css("div[role=status]")
  end
end
