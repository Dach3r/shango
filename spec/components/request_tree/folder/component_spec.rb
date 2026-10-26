require "rails_helper"

RSpec.describe RequestTree::Folder::Component, type: :component do
  it "renders the folder summary" do
    folder = create(:folder, name: "Users")
    branch = ApiClient::Tree::Load::Branch.new(collection: folder.collection, folders: {}, requests: {})
    render_inline(described_class.new(folder:, branch:))

    expect(page).to have_css("summary[data-drag-kind=folder]", text: "Users")
  end
end
