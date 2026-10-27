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

  describe "edge cases" do
    it "rejects a parent id that points nowhere" do
      expect(build(:folder, collection: folder.collection, parent_id: SecureRandom.uuid)).not_to be_valid
    end

    it "rejects a parent from another collection" do
      expect(build(:folder, collection: folder.collection, parent: create(:folder))).not_to be_valid
    end

    it "destroys nested folders and requests", :aggregate_failures do
      child = create(:folder, collection: folder.collection, parent: folder)
      request = create(:api_request, collection: folder.collection, folder: child)
      folder.destroy

      expect(Folder.where(id: child.id)).not_to exist
      expect(ApiRequest.where(id: request.id)).not_to exist
    end

    it "numbers siblings per parent", :aggregate_failures do
      second_root = create(:folder, collection: folder.collection)
      child = create(:folder, collection: folder.collection, parent: folder)

      expect(second_root.position).to be > folder.position
      expect(child.position).to eq(1)
    end

    it "keeps an explicit position on create" do
      expect(create(:folder, collection: folder.collection, position: 9).position).to eq(9)
    end
  end
end
