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
end
