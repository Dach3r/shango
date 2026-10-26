require "rails_helper"

RSpec.describe RequestTree::Collection::Component, type: :component do
  it "renders the collection summary and actions", :aggregate_failures do
    collection = create(:collection, name: "Docs")
    branch = ApiClient::Tree::Load::Branch.new(collection:, folders: {}, requests: {})
    render_inline(described_class.new(branch:))

    expect(page).to have_css("summary", text: "Docs")
    expect(page).to have_link(I18n.t("components.request_tree.new_folder"), visible: :all)
  end
end
