require "rails_helper"

RSpec.describe Bolt::Component, type: :component do
  it "renders an aria-hidden svg with extra options" do
    render_inline(described_class.new(class: "h-7"))

    expect(page).to have_css("svg.h-7[viewbox='0 0 100 120'][aria-hidden='true'] polygon[points='#{described_class::POINTS}']", visible: :all)
  end
end
