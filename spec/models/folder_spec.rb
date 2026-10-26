require "rails_helper"

RSpec.describe Folder do
  subject(:folder) { create(:folder) }

  it { is_expected.to validate_presence_of(:name) }

  describe "auth types" do
    it "allows inherit", :aggregate_failures do
      expect(folder).to be_inherits_auth
      expect(folder.allowed_auth_types).to include("inherit", "none")
    end
  end

  describe "#siblings" do
    it "scopes to the same parent in the collection" do
      create(:folder, collection: folder.collection, parent: folder)
      sibling = create(:folder, collection: folder.collection)

      expect(folder.siblings).to contain_exactly(folder, sibling)
    end
  end

  describe "parent validation" do
    it "rejects a parent from another collection", :aggregate_failures do
      child = build(:folder, collection: folder.collection, parent: create(:folder))

      expect(child).not_to be_valid
      expect(child.errors).to include(:parent)
    end

    it "rejects itself as parent" do
      folder.parent = folder

      expect(folder).not_to be_valid
    end

    it "rejects a descendant as parent" do
      child = create(:folder, collection: folder.collection, parent: folder)
      folder.parent = child

      expect(folder).not_to be_valid
    end

    it "accepts a valid parent" do
      expect(build(:folder, collection: folder.collection, parent: folder)).to be_valid
    end
  end

  describe "#ancestors" do
    it "returns the chain from parent to root", :aggregate_failures do
      child = create(:folder, collection: folder.collection, parent: folder)
      grandchild = create(:folder, collection: folder.collection, parent: child)

      expect(grandchild.ancestors).to eq([child, folder])
      expect(grandchild).to be_descendant_of(folder)
      expect(folder).not_to be_descendant_of(grandchild)
    end

    it "stops on a cycle" do
      child = create(:folder, collection: folder.collection, parent: folder)
      folder.update_column(:parent_id, child.id)

      expect(child.reload.ancestors).to contain_exactly(folder, child)
    end
  end
end
