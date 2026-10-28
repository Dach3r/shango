require "rails_helper"

RSpec.describe RequestTree::Folder::Component, type: :component do
  it "renders the folder summary", :aggregate_failures do
    folder = create(:folder, name: "Users")
    branch = ApiClient::Tree::Load::Branch.new(collection: folder.collection, folders: {}, requests: {})
    render_inline(described_class.new(folder:, branch:))

    expect(page).to have_css("summary[data-drag-kind=folder]", text: "Users")
    expect(page).to have_css("summary span[data-inline-rename-param-value=folder]", text: "Users")
  end

  it "renders open unless its id is in closed_ids", :aggregate_failures do
    folder = create(:folder)
    branch = ApiClient::Tree::Load::Branch.new(collection: folder.collection, folders: {}, requests: {})

    render_inline(described_class.new(folder:, branch:))
    expect(page).to have_css("details[open]")

    render_inline(described_class.new(folder:, branch:, closed_ids: [folder.id.to_s]))
    expect(page).to have_css("details:not([open])")
  end

  it "is neither draggable, renamable nor actionable when the member cannot manage it", :aggregate_failures do
    folder = create(:folder, name: "Users")
    branch = ApiClient::Tree::Load::Branch.new(collection: folder.collection, folders: {}, requests: {})
    render_inline(described_class.new(folder:, branch:, manage: false))

    expect(page).to have_css("summary", text: "Users")
    expect(page).to have_no_css("[draggable], [data-drop-mode], [data-controller=inline-rename], [data-controller=context-menu]", visible: :all)
    expect(page).to have_no_link(I18n.t("components.request_tree.edit"), visible: :all)
  end
end
