require "rails_helper"

RSpec.describe MethodBadge::Component, type: :component do
  it "renders the full method in its color" do
    render_inline(described_class.new(method: "get"))

    expect(page).to have_css("span.text-emerald-700", text: "GET")
  end

  it "abbreviates long methods when short" do
    render_inline(described_class.new(method: "DELETE", short: true))

    expect(page).to have_css("span", text: "DEL")
  end

  it "keeps short methods as is when short" do
    render_inline(described_class.new(method: "GET", short: true))

    expect(page).to have_css("span", text: "GET")
  end

  it "falls back to the muted color for unknown methods" do
    render_inline(described_class.new(method: "TRACE"))

    expect(page).to have_css("span.text-muted", text: "TRACE")
  end

  it "tags the badge with its request so the client can update it" do
    render_inline(described_class.new(method: "GET", request_id: "abc"))

    expect(page).to have_css("span[data-method-badge='abc']")
  end

  it "exposes the short label and classes of every method" do
    expect(described_class.presets["DELETE"]).to eq(label: "DEL", classes: "#{described_class::BASE} text-danger")
  end
end
