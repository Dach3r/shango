require "rails_helper"

RSpec.describe RequestTree::Folder::Component, type: :component do
  it "renders the folder summary", :aggregate_failures do
    folder = create(:folder, name: "Users")
    branch = ApiClient::Tree::Load::Branch.new(collection: folder.collection, folders: {}, requests: {})
    render_inline(described_class.new(folder:, branch:))

    expect(page).to have_css("summary[data-drag-kind=folder]", text: "Users")
    expect(page).to have_css("summary span[data-inline-rename-param-value=folder]", text: "Users")
  end
end
