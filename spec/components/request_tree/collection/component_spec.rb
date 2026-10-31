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

  it "offers to run the collection and to see its runs, even to a member who cannot manage it", :aggregate_failures do
    collection = create(:collection)
    branch = ApiClient::Tree::Load::Branch.new(collection:, folders: {}, requests: {})
    render_inline(described_class.new(branch:, manage: false))

    expect(page).to have_css("a[href='/workbench/collections/#{collection.id}/runs/new']", text: I18n.t("components.request_tree.run"), visible: :all)
    expect(page).to have_css("a[href='/workbench/collections/#{collection.id}/runs']", text: I18n.t("components.request_tree.run_history"), visible: :all)
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

  it "is neither a drop target, renamable nor actionable when the member cannot manage it", :aggregate_failures do
    collection = create(:collection, name: "Docs")
    branch = ApiClient::Tree::Load::Branch.new(collection:, folders: {}, requests: {})
    render_inline(described_class.new(branch:, manage: false))

    expect(page).to have_css("summary", text: "Docs")
    expect(page).to have_no_css("[data-drop-mode], [data-controller=inline-rename], [data-controller=context-menu]", visible: :all)
    expect(page).to have_no_link(I18n.t("components.request_tree.new_folder"), visible: :all)
  end

  it "offers the export to members who cannot manage the collection", :aggregate_failures do
    collection = create(:collection)
    branch = ApiClient::Tree::Load::Branch.new(collection:, folders: {}, requests: {})
    render_inline(described_class.new(branch:, manage: false))

    expect(page).to have_link(I18n.t("components.request_tree.export"), href: "/workbench/collections/#{collection.id}/exports/new", visible: :all)
    expect(page).to have_no_button(I18n.t("components.request_tree.delete"), visible: :all)
  end
end
