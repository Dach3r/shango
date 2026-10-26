require "rails_helper"

RSpec.describe Modal::Component, type: :component do
  it "renders header, content and the default footer", :aggregate_failures do
    render_inline(described_class.new(title: "Title", description: "Desc", icon: "rocket", size: :lg, form: "f", submit: "Save")) { "Body" }

    expect(page).to have_css("dialog.max-w-2xl h2", text: "Title", visible: :all)
    expect(page.text(:all)).to include("Desc")
    expect(page).to have_css("dialog header svg", visible: :all)
    expect(page.text(:all)).to include("Body")
    expect(page).to have_css("footer button[type=submit][form=f]", text: "Save", visible: :all)
    expect(page).to have_css("footer button", text: I18n.t("components.modal.cancel"), visible: :all)
  end

  it "omits icon, description, cancel and backdrop dismissal when asked", :aggregate_failures do
    render_inline(described_class.new(title: "Title", submit: "Save", cancel: false, dismissible: false)) { "Body" }

    expect(page).to have_no_css("header > span", visible: :all)
    expect(page).to have_no_css("header p", visible: :all)
    expect(page).to have_no_css("footer button[type=button]", visible: :all)
    expect(page).to have_no_css("dialog[data-action*='dialog#backdrop']", visible: :all)
  end

  it "renders a custom footer slot" do
    render_inline(described_class.new(title: "Title")) do |modal|
      modal.with_footer { "Custom" }
    end

    expect(page).to have_css("footer", text: "Custom", visible: :all)
  end

  it "renders no footer without submit or slot" do
    render_inline(described_class.new(title: "Title"))

    expect(page).to have_no_css("footer", visible: :all)
  end
end
