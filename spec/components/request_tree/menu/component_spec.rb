require "rails_helper"

RSpec.describe RequestTree::Menu::Component, type: :component do
  it "renders its label and content" do
    render_inline(described_class.new(label: "Actions")) { "Items" }

    expect(page.text(:all)).to include("Items")
  end
end
