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
end
