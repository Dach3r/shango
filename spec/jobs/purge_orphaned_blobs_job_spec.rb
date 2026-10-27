require "rails_helper"

RSpec.describe PurgeOrphanedBlobsJob do
  include ActiveJob::TestHelper

  def blob(created_at)
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new("data"), filename: "f.txt").tap { |record| record.update!(created_at:) }
  end

  it "purges old unattached blobs only", :aggregate_failures do
    old = blob(3.days.ago)
    fresh = blob(1.hour.ago)
    attached = blob(3.days.ago)
    ActiveStorage::Attachment.create!(name: "binary_body", record: create(:api_request), blob: attached)

    described_class.perform_now

    expect(ActiveStorage::PurgeJob).to have_been_enqueued.once
    expect { perform_enqueued_jobs }.to change(ActiveStorage::Blob, :count).by(-1)
    expect(ActiveStorage::Blob.exists?(old.id)).to be(false)
    expect(ActiveStorage::Blob.where(id: [fresh.id, attached.id]).count).to eq(2)
  end

  it "does nothing without orphans" do
    expect { described_class.perform_now }.not_to have_enqueued_job(ActiveStorage::PurgeJob)
  end

  it "keeps blobs inside the grace period" do
    blob(PurgeOrphanedBlobsJob::GRACE_PERIOD.ago + 1.minute)
    described_class.perform_now

    expect(ActiveStorage::PurgeJob).not_to have_been_enqueued
  end

  it "is idempotent once the blobs are purged", :aggregate_failures do
    blob(3.days.ago)
    described_class.perform_now
    perform_enqueued_jobs

    expect { described_class.perform_now }.not_to change(ActiveStorage::Blob, :count)
  end
end
