require "rails_helper"

RSpec.describe RequestTree::Collection::Component, type: :component do
  it "renders the collection summary and actions", :aggregate_failures do
    collection = create(:collection, name: "Docs")
    branch = ApiClient::Tree::Load::Branch.new(collection:, folders: {}, requests: {})
    render_inline(described_class.new(branch:))

    expect(page).to have_css("summary", text: "Docs")
    expect(page).to have_css("summary span[data-controller=inline-rename][data-inline-rename-param-value=collection]", text: "Docs")
    expect(page).to have_link(I18n.t("components.request_tree.new_folder"), visible: :all)
  end

  it "renders open unless its id is in closed_ids", :aggregate_failures do
    collection = create(:collection)
    branch = ApiClient::Tree::Load::Branch.new(collection:, folders: {}, requests: {})

    render_inline(described_class.new(branch:))
    expect(page).to have_css("details[open]")

    render_inline(described_class.new(branch:, closed_ids: [collection.id.to_s]))
    expect(page).to have_css("details:not([open])")
  end

  it "escapes hostile collection names", :aggregate_failures do
    collection = create(:collection, name: "<script>alert(1)</script>")
    branch = ApiClient::Tree::Load::Branch.new(collection:, folders: {}, requests: {})
    render_inline(described_class.new(branch:))

    expect(page).not_to have_css("script", visible: :all)
    expect(page).to have_css("summary", text: "<script>alert(1)</script>")
  end
end
