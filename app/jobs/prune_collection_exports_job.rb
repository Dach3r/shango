# Finished exports hold the file (maybe with credentials), so they are deleted once they expire (SHANGO_EXPORT_RETENTION_MINUTES, default 60).
class PruneCollectionExportsJob < ApplicationJob
  queue_as :default

  def perform
    CollectionExport.expired.in_batches(of: 500).delete_all
  end
end
