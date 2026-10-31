require "rails_helper"

RSpec.describe PruneCollectionRunsJob do
  it "deletes finished runs past the retention, with their items", :aggregate_failures do
    old = create(:collection_run, :completed, finished_at: 40.days.ago)
    create(:collection_run_item, collection_run: old)
    kept = create(:collection_run, :completed)
    active = create(:collection_run, :running)

    described_class.perform_now

    expect(CollectionRun.all).to contain_exactly(kept, active)
    expect(CollectionRunItem.count).to eq(0)
  end

  it "keeps everything when the retention is 0" do
    old = create(:collection_run, :completed, finished_at: 400.days.ago)
    stub_const("ENV", ENV.to_h.merge("SHANGO_RUN_RETENTION_DAYS" => "0"))

    described_class.perform_now

    expect(CollectionRun.all).to contain_exactly(old)
  end

  it "keeps only the last runs of a collection" do
    collection = create(:collection)
    stub_const("CollectionRun::KEEP_PER_COLLECTION", 2)
    runs = Array.new(4) { |index| create(:collection_run, :completed, project: collection.project, collection:, created_at: index.hours.ago) }

    described_class.perform_now

    expect(CollectionRun.all).to contain_exactly(runs[0], runs[1])
  end
end
