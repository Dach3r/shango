require "rails_helper"

RSpec.describe EmptyState::Component, type: :component do
  it "renders icon, title, description and actions", :aggregate_failures do
    render_inline(described_class.new(icon: "send", title: "Nothing", description: "Add one.", class: "extra", id: "empty")) { "Action" }

    expect(page).to have_css("div#empty.extra svg")
    expect(page).to have_css("h2", text: "Nothing")
    expect(page).to have_css("p", text: "Add one.")
    expect(page).to have_css("div.gap-2", text: "Action")
  end

  it "omits description and actions when not given", :aggregate_failures do
    render_inline(described_class.new(icon: "send", title: "Nothing"))

    expect(page).to have_no_css("p")
    expect(page).to have_no_css("div.gap-2")
  end
end
