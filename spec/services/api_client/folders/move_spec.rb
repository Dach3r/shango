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

  describe "edge cases" do
    it "fails when moving under a descendant and leaves the tree untouched", :aggregate_failures do
      grandchild = create(:folder, collection:, parent: folder)
      result = described_class.call(folder: target, parent_id: grandchild.id)

      expect(result).to be_failure
      expect(target.reload.parent_id).to be_nil
    end

    it "fails when moving a folder into itself" do
      expect(described_class.call(folder: target, parent_id: target.id)).to be_failure
    end

    it "keeps the same parent when it already is there", :aggregate_failures do
      result = described_class.call(folder:, parent_id: target.id)

      expect(result).to be_success
      expect(folder.reload.parent).to eq(target)
    end

    it "raises when the parent does not exist" do
      expect { described_class.call(folder:, parent_id: SecureRandom.uuid) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "moves deep subtrees with their descendants", :aggregate_failures do
      leaf = create(:folder, collection:, parent: folder)
      destination = create(:folder, collection:)
      described_class.call(folder: target, parent_id: destination.id)

      expect(leaf.reload.ancestors).to eq([folder, target, destination])
    end
  end
end
