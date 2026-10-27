class Cookie < ApplicationRecord
  MAX_PER_JAR = 200

  belongs_to :project
  belongs_to :environment, optional: true

  encrypts :value

  validates :name, :domain, :path, presence: true

  scope :ordered, -> { order(:domain, :path, :name) }
  scope :for_jar, ->(project, environment) { where(project:, environment:) }
  scope :live, -> { where(expires_at: nil).or(where(expires_at: Time.current..)) }
  scope :expired, -> { where(expires_at: ...Time.current) }

  def matches?(uri)
    host_matches?(uri.host.to_s.downcase) && path_matches?(uri.path.presence || "/") && (!secure || uri.scheme == "https")
  end

  private

  def host_matches?(host)
    host == domain || (!host_only && host.end_with?(".#{domain}"))
  end

  def path_matches?(request_path)
    return true if request_path == path

    request_path.start_with?(path) && (path.end_with?("/") || request_path[path.length] == "/")
  end
end
