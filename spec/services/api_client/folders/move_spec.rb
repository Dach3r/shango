require "rails_helper"

RSpec.describe ApiClient::Folders::Move do
  let(:collection) { create(:collection) }
  let(:target) { create(:folder, collection:) }
  let(:folder) { create(:folder, collection:, parent: target) }

  it "moves the folder to the collection root" do
    result = described_class.call(folder:, parent_id: "")

    expect(result).to be_success
    expect(folder.reload.parent_id).to be_nil
  end

  it "moves the folder under another folder before a sibling", :aggregate_failures do
    other = create(:folder, collection:)
    sibling = create(:folder, collection:, parent: other)

    described_class.call(folder:, parent_id: other.id, before_id: sibling.id)

    expect(folder.reload.parent).to eq(other)
    expect(folder.position).to be < sibling.reload.position
  end

  it "fails when the folder would become its own parent" do
    result = described_class.call(folder: target, parent_id: folder.id)

    expect(result).to be_failure
  end

  it "raises when the parent is outside the collection" do
    foreign = create(:folder)

    expect { described_class.call(folder:, parent_id: foreign.id) }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
