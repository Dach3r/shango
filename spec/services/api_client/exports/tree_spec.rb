require "rails_helper"

RSpec.describe ApiClient::Exports::Tree do
  it "walks folders and requests in sidebar order", :aggregate_failures do
    collection = create(:collection)
    second = create(:folder, collection:, name: "B", position: 2)
    first = create(:folder, collection:, name: "A", position: 1)
    nested = create(:folder, collection:, name: "Nested", parent: first)
    inside = create(:api_request, collection:, folder: nested)
    root = create(:api_request, collection:)
    tree = described_class.new(collection)

    expect(tree.folders_in).to eq([first, second])
    expect(tree.folders_in(first)).to eq([nested])
    expect(tree.requests_in).to eq([root])
    expect(tree.requests_in(nested)).to eq([inside])
    expect(tree.requests_in(second)).to eq([])
  end
end
