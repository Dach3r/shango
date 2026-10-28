class Cookie < ApplicationRecord
  MAX_PER_JAR = 200
  MAX_VALUE_LENGTH = 4096
  DOMAIN_FORMAT = %r{\A[^\s/]+\z}
  IP_HOST = /\A[\d.]+\z|:/

  belongs_to :project
  belongs_to :environment, optional: true

  encrypts :value

  validates :name, :domain, :path, presence: true
  validates :value, length: { maximum: MAX_VALUE_LENGTH }
  validates :domain, format: { with: DOMAIN_FORMAT }, allow_blank: true
  validates :path, format: { with: %r{\A/[^\r\n]*\z} }, allow_blank: true
  validates :name, uniqueness: { scope: %i[project_id environment_id domain path] }
  validate :domain_scope

  scope :ordered, -> { order(:domain, :path, :name) }
  scope :for_jar, ->(project, environment) { where(project:, environment:) }
  scope :live, -> { where(expires_at: nil).or(where(expires_at: Time.current..)) }
  scope :expired, -> { where(expires_at: ...Time.current) }

  # A domain a cookie can be shared with subdomains from: not an IP and not a public suffix (com, co.uk, github.io).
  def self.shareable_domain?(domain)
    !domain.match?(IP_HOST) && PublicSuffix.valid?(domain)
  end

  # Keeps a jar within MAX_PER_JAR by dropping its least recently updated cookies.
  def self.trim(project, environment)
    jar = for_jar(project, environment)
    excess = jar.count - MAX_PER_JAR
    jar.order(:updated_at).limit(excess).destroy_all if excess.positive?
  end

  def matches?(uri)
    host_matches?(uri.host.to_s.downcase) && path_matches?(uri.path.presence || "/") && (!secure || uri.scheme == "https")
  end

  private

  # A cookie shared with subdomains needs a registrable domain, never an IP or a public suffix.
  def domain_scope
    return if host_only || domain.blank?

    errors.add(:domain, :invalid) unless self.class.shareable_domain?(domain)
  end

  def host_matches?(host)
    host == domain || (!host_only && host.end_with?(".#{domain}"))
  end

  def path_matches?(request_path)
    return true if request_path == path

    request_path.start_with?(path) && (path.end_with?("/") || request_path[path.length] == "/")
  end
end
