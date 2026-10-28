require "rails_helper"

RSpec.describe PruneCollectionExportsJob do
  it "deletes exports past their expiry" do
    create(:collection_export, :done, expires_at: 1.minute.ago)
    kept = create(:collection_export)

    described_class.perform_now

    expect(CollectionExport.all).to contain_exactly(kept)
  end
end
