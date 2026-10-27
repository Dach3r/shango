require "rails_helper"

RSpec.describe ApiClient::Requests::Move do
  let(:project) { create(:project) }
  let(:collection) { create(:collection, project:) }
  let(:folder) { create(:folder, collection:) }
  let(:api_request) { create(:api_request, collection:) }

  it "moves into a folder of the same collection" do
    result = described_class.call(api_request:, folder_id: folder.id)

    expect(result).to be_success
    expect(api_request.reload.folder).to eq(folder)
  end

  it "moves to the root of another collection before a sibling", :aggregate_failures do
    other = create(:collection, project:)
    sibling = create(:api_request, collection: other)

    described_class.call(api_request:, collection_id: other.id, folder_id: "", before_id: sibling.id)

    expect(api_request.reload.collection).to eq(other)
    expect(api_request.folder).to be_nil
    expect(api_request.position).to be < sibling.reload.position
  end

  it "raises for collections of another project" do
    foreign = create(:collection)

    expect { described_class.call(api_request:, collection_id: foreign.id) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "fails when the request becomes invalid" do
    allow(api_request).to receive(:save).and_return(false)

    expect(described_class.call(api_request:)).to be_failure
  end

  describe "edge cases" do
    it "raises for a folder of another collection of the same project" do
      other = create(:collection, project:)
      foreign_folder = create(:folder, collection: other)

      expect { described_class.call(api_request:, collection_id: collection.id, folder_id: foreign_folder.id) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "raises when the folder does not exist" do
      expect { described_class.call(api_request:, folder_id: SecureRandom.uuid) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "orders a moved request after the existing ones when before_id is blank", :aggregate_failures do
      create(:api_request, collection:)
      described_class.call(api_request:, before_id: "")

      expect(collection.api_requests.order(:position).last).to eq(api_request)
    end

    it "keeps a request at the same place when moved before itself", :aggregate_failures do
      other = create(:api_request, collection:)
      described_class.call(api_request:, before_id: api_request.id)

      expect(collection.api_requests.order(:position).map(&:id)).to eq([other.id, api_request.id])
    end
  end
end
