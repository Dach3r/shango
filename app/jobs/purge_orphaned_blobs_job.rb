# Uploads are attached after the blob is created, so a failed save can leave blobs nobody references.
class PurgeOrphanedBlobsJob < ApplicationJob
  queue_as :default

  GRACE_PERIOD = 2.days

  def perform
    ActiveStorage::Blob.unattached.where(created_at: ..GRACE_PERIOD.ago).find_each(&:purge_later)
  end
end
