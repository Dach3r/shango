require "rails_helper"

RSpec.describe ResponseReferenceModal::Component, type: :component do
  let(:responses) do
    [{ id: "a1", name: "sign_in", method: "POST", folder: "Auth" }, { id: "b2", name: "list", method: "GET", folder: nil }]
  end

  it "renders nothing without other requests" do
    render_inline(described_class.new(responses: []))

    expect(page).to have_no_css("template", visible: :all)
  end

  def template
    Capybara.string(Nokogiri::HTML5.fragment(rendered_content).at_css("template").children.to_html)
  end

  it "offers the attributes and the requests of the collection", :aggregate_failures do
    render_inline(described_class.new(responses:))

    expect(page).to have_css("template#response-reference-template", visible: :all)
    expect(template).to have_css("input[name=attribute][value=body]", visible: :all)
    expect(template).to have_css("button[role=option][data-value=raw]", visible: :all)
    expect(template).to have_css("button[role=option][data-value=a1][data-label='[Auth] POST sign_in']", visible: :all)
    expect(template).to have_css("button[role=option][data-value=b2][data-label='GET list']", visible: :all)
  end

  it "renders the fixed function and trigger selects disabled" do
    render_inline(described_class.new(responses:))

    expect(template).to have_css("input[name=function] ~ button[disabled], input[name=trigger] ~ button[disabled]", visible: :all, count: 2)
  end
end
