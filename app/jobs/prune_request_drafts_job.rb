# Drafts untouched for longer than the retention window are deleted (SHANGO_DRAFT_RETENTION_DAYS, default 30; 0 keeps everything).
class PruneRequestDraftsJob < ApplicationJob
  queue_as :default

  DEFAULT_DAYS = 30

  def perform
    days = ENV.fetch("SHANGO_DRAFT_RETENTION_DAYS", DEFAULT_DAYS).to_i
    ApiClient::Drafts::Prune.call(days:) if days.positive?
  end
end
