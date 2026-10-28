# A queued export of a collection (see ExportCollectionJob). The finished file is kept encrypted until it expires,
# because it may hold credentials; only the member who asked for it can download it.
class CollectionExport < ApplicationRecord
  DEFAULT_RETENTION_MINUTES = 60

  belongs_to :project
  belongs_to :collection
  belongs_to :user

  enum :export_format, { postman: "postman", insomnia: "insomnia", openapi: "openapi", shango: "shango" }, prefix: :format
  enum :status, { queued: "queued", running: "running", done: "done", failed: "failed" }

  encrypts :content

  scope :expired, -> { where(expires_at: ..Time.current) }

  def self.retention
    ENV.fetch("SHANGO_EXPORT_RETENTION_MINUTES", DEFAULT_RETENTION_MINUTES).to_i.clamp(1, 24 * 60).minutes
  end

  def expired?
    expires_at <= Time.current
  end

  def active?
    (queued? || running?) && !expired?
  end

  def downloadable?
    done? && !expired?
  end

  def file_content
    Base64.strict_decode64(content)
  end
end
