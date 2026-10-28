# Builds a CollectionExport outside the web thread, updating its progress for the browser, which polls it.
class ExportCollectionJob < ApplicationJob
  queue_as :exports

  # A member's exports queue up one at a time instead of occupying every worker.
  limits_concurrency to: 1, key: ->(user_id, *) { user_id }, duration: 5.minutes

  def perform(user_id, export_id)
    export = CollectionExport.find_by(id: export_id)
    return unless export&.queued?

    build(user_id, export)
  end

  private

  def build(user_id, export)
    export.update!(status: :running)
    result = ApiClient::Exports::Export.call(
      collection: export.collection, format: export.export_format, include_environments: export.include_environments, include_credentials: export.include_credentials,
      on_progress: ->(percent) { export.update_columns(progress: percent, updated_at: Time.current) }
    )
    finish(export, result.data)
  rescue StandardError => error
    Rails.logger.error("ExportCollectionJob #{export.id} failed (user #{user_id}): #{error.class}: #{error.message}")
    export.update_columns(status: "failed", error: "unexpected", updated_at: Time.current)
  end

  def finish(export, data)
    export.update!(
      status: :done, progress: 100, filename: data[:filename], content_type: data[:content_type],
      content: Base64.strict_encode64(data[:content]), expires_at: CollectionExport.retention.from_now
    )
  end
end
