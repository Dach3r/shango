# Runs older than SHANGO_RUN_RETENTION_DAYS (default 30; 0 keeps them) are deleted daily, and no collection keeps more than its last 20.
class PruneCollectionRunsJob < ApplicationJob
  queue_as :default

  def perform
    days = CollectionRun.retention_days
    CollectionRun.finished_before(days.days.ago).in_batches(of: 500).destroy_all if days.positive?
    CollectionRun.where(status: %w[completed failed cancelled]).group(:collection_id).having("COUNT(*) > ?", CollectionRun::KEEP_PER_COLLECTION).pluck(:collection_id).each { |id| trim(id) }
  end

  private

  def trim(collection_id)
    stale = CollectionRun.where(collection_id:, status: %w[completed failed cancelled]).recent.offset(CollectionRun::KEEP_PER_COLLECTION).pluck(:id)
    CollectionRun.where(id: stale).destroy_all
  end
end
