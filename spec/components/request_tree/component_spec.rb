require "rails_helper"

RSpec.describe RequestTree::Component, type: :component do
  let(:project) { create(:project) }

  it "renders an empty state without branches" do
    render_inline(described_class.new(branches: [], folder_toggle: "double_click", request_open: "click"))

    expect(page).to have_text(I18n.t("components.request_tree.empty"))
  end

  it "renders collections, folders, nested folders and requests", :aggregate_failures do
    collection = create(:collection, project:, name: "Docs")
    folder = create(:folder, collection:, name: "Users")
    create(:folder, collection:, parent: folder, name: "Nested")
    root_request = create(:api_request, collection:, name: "Root request")
    inner_request = create(:api_request, collection:, folder:, name: "Inner request")
    create(:collection, project:, name: "Empty")

    render_inline(described_class.new(branches: ApiClient::Tree::Load.call(project:), folder_toggle: "click", request_open: "click", current_request_id: inner_request.id))

    expect(page).to have_no_text(I18n.t("components.request_tree.empty"))
    expect(page).to have_text("Docs")
    expect(page).to have_text("Nested")
    expect(page).to have_link("Root request", href: "/workbench/requests/#{root_request.id}")
    expect(page).to have_css("a[aria-current=page]", text: "Inner request")
    expect(page).to have_css("li", text: I18n.t("components.request_tree.empty_collection"))
  end

  it "exposes the click preferences to the tree controller" do
    render_inline(described_class.new(branches: [], folder_toggle: "click", request_open: "double_click"))

    expect(page).to have_css("nav[data-tree-toggle-value=click][data-tree-open-value=double_click]")
  end
end
