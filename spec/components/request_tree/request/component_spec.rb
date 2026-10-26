require "rails_helper"

RSpec.describe RequestTree::Request::Component, type: :component do
  let(:api_request) { create(:api_request, name: "List", http_method: "POST") }

  it "renders an inactive request", :aggregate_failures do
    render_inline(described_class.new(api_request:))

    expect(page).to have_css("li[data-drag-kind=request] a.text-body:not([aria-current])", text: "List")
    expect(page).to have_text("POST")
  end

  it "highlights the active request" do
    render_inline(described_class.new(api_request:, active: true))

    expect(page).to have_css("a[aria-current=page].font-medium")
  end
end
