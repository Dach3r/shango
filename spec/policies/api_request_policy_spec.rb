require "rails_helper"

RSpec.describe ApiRequestPolicy, type: :policy do
  let(:project) { create(:project) }
  let(:owner) { owner_membership(project:) }
  let(:member) { member_membership(project:) }
  let(:stranger) { member_membership(project:) }
  let(:collection) { create(:collection, project:, creator: member.user) }
  let(:api_request) { create(:api_request, collection:) }
  let(:draft) { create(:api_request, project:, collection: nil, user: member.user) }

  describe "in a collection" do
    it "lets the collection's creator and the owners manage it", :aggregate_failures do
      [member, owner].each do |membership|
        policy = described_class.new(membership, api_request)

        expect(policy).to be_create
        expect(policy).to be_update
        expect(policy).to be_destroy
        expect(policy).to be_duplicate
      end
    end

    it "lets any member see and send it but not change it", :aggregate_failures do
      policy = described_class.new(stranger, api_request)

      expect(policy).to be_show
      expect(policy).to be_execute
      expect(policy).not_to be_create
      expect(policy).not_to be_update
      expect(policy).not_to be_destroy
      expect(policy).not_to be_duplicate
    end

    it "is out of reach in another project", :aggregate_failures do
      policy = described_class.new(owner_membership, api_request)

      expect(policy).not_to be_show
      expect(policy).not_to be_update
    end
  end

  describe "as a draft" do
    it "belongs to its author", :aggregate_failures do
      policy = described_class.new(member, draft)

      expect(policy).to be_show
      expect(policy).to be_create
      expect(policy).to be_update
      expect(policy).to be_destroy
    end

    it "is private to its author, owners included", :aggregate_failures do
      policy = described_class.new(owner, draft)

      expect(policy).not_to be_show
      expect(policy).not_to be_create
      expect(policy).not_to be_update
    end
  end
end
