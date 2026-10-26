require "rails_helper"

RSpec.describe RequestTree::Component, type: :component do
  let(:project) { create(:project) }

  it "renders an empty state without branches" do
    render_inline(described_class.new(branches: [], history_groups: [], folder_toggle: "double_click", request_open: "click"))

    expect(page).to have_text(I18n.t("components.request_tree.empty"))
  end

  it "links to the import modal" do
    render_inline(described_class.new(branches: [], history_groups: [], folder_toggle: "double_click", request_open: "click"))

    expect(page).to have_link(I18n.t("components.request_tree.import"), href: "/workbench/import/new")
  end

  it "renders the history view with a back button and an empty state", :aggregate_failures do
    render_inline(described_class.new(branches: [], history_groups: [], folder_toggle: "double_click", request_open: "click"))

    expect(page).to have_css("[data-sidebar-view-target=history][hidden]", text: I18n.t("components.request_tree.history_title"), visible: :all)
    expect(page).to have_css("button[data-action='sidebar-view#showHistory']")
    expect(page).to have_css("button[data-action='sidebar-view#showCollections']", visible: :all)
    expect(page).to have_css("[data-sidebar-view-target=history]", text: I18n.t("components.request_tree.history_empty"), visible: :all)
  end

  it "lists history grouped by collection and drafts", :aggregate_failures do
    collection = create(:collection, project:, name: "Docs")
    user = create(:user)
    api_request = create(:api_request, collection:, name: "Fetch users")
    draft = create(:api_request, project:, collection: nil, user:, name: "Scratch")
    groups = [
      ApiClient::Executions::History::Group.new(collection:, executions: [create(:request_execution, api_request:, user:, url: "https://api.example.com/users")]),
      ApiClient::Executions::History::Group.new(collection: nil, executions: [create(:request_execution, api_request: draft, user:)])
    ]

    render_inline(described_class.new(branches: [], history_groups: groups, folder_toggle: "click", request_open: "click"))

    expect(page).to have_link("Fetch users", href: "/workbench/requests/#{api_request.id}", visible: :all)
    expect(page).to have_css("[data-sidebar-view-target=history]", text: "https://api.example.com/users", visible: :all)
    expect(page).to have_css("[data-sidebar-view-target=history]", text: I18n.t("components.request_tree.drafts"), visible: :all)
    expect(page).to have_link("Scratch", visible: :all)
  end

  it "renders collections, folders, nested folders and requests", :aggregate_failures do
    collection = create(:collection, project:, name: "Docs")
    folder = create(:folder, collection:, name: "Users")
    create(:folder, collection:, parent: folder, name: "Nested")
    root_request = create(:api_request, collection:, name: "Root request")
    inner_request = create(:api_request, collection:, folder:, name: "Inner request")
    create(:collection, project:, name: "Empty")

    render_inline(described_class.new(branches: ApiClient::Tree::Load.call(project:), history_groups: [], folder_toggle: "click", request_open: "click", current_request_id: inner_request.id))

    expect(page).to have_no_text(I18n.t("components.request_tree.empty"))
    expect(page).to have_text("Docs")
    expect(page).to have_text("Nested")
    expect(page).to have_link("Root request", href: "/workbench/requests/#{root_request.id}")
    expect(page).to have_css("a[aria-current=page]", text: "Inner request")
    expect(page).to have_css("li", text: I18n.t("components.request_tree.empty_collection"))
  end

  it "exposes the click preferences to the tree controller" do
    render_inline(described_class.new(branches: [], history_groups: [], folder_toggle: "click", request_open: "double_click"))

    expect(page).to have_css("nav[data-tree-toggle-value=click][data-tree-open-value=double_click]")
  end

  it "exposes the collapse nested preference to the tree controller" do
    render_inline(described_class.new(branches: [], history_groups: [], folder_toggle: "click", request_open: "click", collapse_nested: false))

    expect(page).to have_css("nav[data-tree-collapse-nested-value=false]")
  end
end
