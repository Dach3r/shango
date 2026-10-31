require "rails_helper"

RSpec.describe ApiClient::Runs::Scope do
  let(:collection) { create(:collection) }

  def request(name, folder: nil)
    create(:api_request, collection:, folder:, name:)
  end

  it "lists subfolders first, recursively, then the requests of each container, as the sidebar does", :aggregate_failures do
    first = create(:folder, collection:, name: "first")
    second = create(:folder, collection:, name: "second")
    nested = create(:folder, collection:, parent: first, name: "nested")
    request("root")
    request("in first", folder: first)
    request("in nested", folder: nested)
    request("in second", folder: second)

    expect(described_class.call(collection:).record.map(&:name)).to eq(["in nested", "in first", "in second", "root"])
  end

  it "limits itself to a folder and what is below it", :aggregate_failures do
    folder = create(:folder, collection:)
    child = create(:folder, collection:, parent: folder)
    request("outside")
    request("inside", folder:)
    request("deeper", folder: child)

    expect(described_class.call(collection:, folder:).record.map(&:name)).to eq(%w[deeper inside])
  end

  it "keeps the order the user gave" do
    a = request("a")
    b = request("b")
    b.update!(position: 0)
    a.update!(position: 5)

    expect(described_class.call(collection:).record.map(&:name)).to eq(%w[b a])
  end

  it "is empty for an empty collection" do
    expect(described_class.call(collection:).record).to eq([])
  end
end
