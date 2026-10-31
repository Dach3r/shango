# A check that Shango runs on a schedule against something a project depends on (see docs/monitoring.md). Named
# UptimeMonitor because Ruby already defines ::Monitor. The fields of each kind live in `settings` and are validated
# per kind; the kind cannot change after creation. Every change to what is checked bumps `config_version`, so a check
# enqueued before the change is discarded. `status` is an AASM state machine: it only moves through its events.
class UptimeMonitor < ApplicationRecord
  include AASM

  INTERVALS = [60, 120, 300, 600, 900, 1800, 3600].freeze
  DOMAIN_INTERVALS = [21_600, 43_200, 86_400].freeze
  PUSH_INTERVALS = [60, 300, 600, 900, 1800, 3600, 7200, 21_600, 43_200, 86_400, 604_800].freeze
  GRACES = [0, 60, 300, 900, 1800, 3600, 21_600, 86_400].freeze
  TIMEOUTS = (1..30)
  CONFIRMATIONS = (1..5)
  HTTP_METHODS = %w[GET HEAD].freeze
  MODES = %w[url request].freeze
  STATUS_LIST = /\A\d{3}(-\d{3})?(,\d{3}(-\d{3})?)*\z/
  MAX_URL_LENGTH = 2048
  MAX_HOST_LENGTH = 253
  DEFAULT_PER_PROJECT = 50
  DEFAULTS = {
    "http" => { "mode" => "url", "http_method" => "GET", "expected_statuses" => "200-399" },
    "ssl" => { "port" => 443, "days_before" => 14 },
    "domain" => { "days_before" => 30 },
    "push" => { "grace" => 300 }
  }.freeze
  SETTINGS = {
    "http" => %w[mode url http_method expected_statuses max_response_ms], "tcp" => %w[host port], "ssl" => %w[host port days_before],
    "domain" => %w[host days_before], "push" => %w[grace]
  }.freeze
  INTEGER_SETTINGS = %w[max_response_ms port days_before grace].freeze
  CONFIG_ATTRIBUTES = %w[enabled interval timeout confirmations settings environment_id api_request_id].freeze

  belongs_to :project
  belongs_to :creator, class_name: "User", optional: true
  belongs_to :environment, optional: true
  belongs_to :api_request, optional: true

  has_many :check_results, dependent: :delete_all
  has_many :check_rollups, dependent: :delete_all
  has_many :incidents, dependent: :delete_all
  has_many :monitor_channels, dependent: :delete_all
  has_many :notification_channels, through: :monitor_channels

  enum :kind, { http: "http", tcp: "tcp", ssl: "ssl", domain: "domain", push: "push" }, validate: true
  enum :status, { pending: "pending", up: "up", down: "down" }

  aasm column: :status, enum: true, create_scopes: false, no_direct_assignment: true, whiny_transitions: true do
    state :pending, initial: true
    state :up, :down

    after_all_transitions :stamp_status_change

    event :go_up do
      transitions from: %i[pending down], to: :up
    end

    event :go_down do
      transitions from: %i[pending up], to: :down
    end

    event :restart do
      transitions from: %i[pending up down], to: :pending
    end
  end

  # The monitors of one environment plus those that belong to none (push monitors, for instance); every monitor without one.
  scope :in_environment, ->(environment) { environment ? where(environment_id: [environment.id, nil]) : all }

  store_accessor :settings, :mode, :url, :http_method, :expected_statuses, :max_response_ms, :host, :port, :days_before, :grace

  after_initialize :fill_defaults, if: :new_record?
  before_validation :normalize_settings
  before_save :remember_environment
  before_update :bump_config_version

  validates :name, presence: true, length: { maximum: 100 }
  validates :timeout, inclusion: { in: TIMEOUTS }
  validates :confirmations, inclusion: { in: CONFIRMATIONS }
  validate :interval_of_kind
  validate :settings_of_kind
  validate :references_in_project
  validate :kind_unchanged, on: :update
  validate :channels_within_limit
  validate :within_limits, on: :create

  def self.per_project_limit
    ENV.fetch("SHANGO_MONITORS_PER_PROJECT", DEFAULT_PER_PROJECT).to_i.clamp(1, 10_000)
  end

  # Install-wide cap; none unless the operator sets one.
  def self.total_limit
    ENV["SHANGO_MONITORS_TOTAL"].presence&.to_i
  end

  def self.digest(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  def self.find_by_push_token(token)
    find_by(push_token_digest: digest(token)) if token.present?
  end

  def paused?
    !enabled
  end

  # When a push monitor without a ping since `since` turns overdue.
  def push_deadline(since)
    since + interval.to_i.seconds + (grace || DEFAULTS["push"]["grace"]).to_i.seconds
  end

  # A new random push token; only its digest is kept, so the token is returned to be shown once.
  def regenerate_push_token
    SecureRandom.urlsafe_base64(32).tap { |token| self.push_token_digest = self.class.digest(token) }
  end

  def intervals
    return DOMAIN_INTERVALS if domain?

    push? ? PUSH_INTERVALS : INTERVALS
  end

  private

  def stamp_status_change(at = Time.current)
    self.last_status_change_at = at
  end

  # A new form starts with the defaults of its kind (port 443 for SSL, for instance).
  def fill_defaults
    self.settings = DEFAULTS.fetch(kind.to_s, {}).merge(settings.to_h.stringify_keys)
  end

  def normalize_settings
    kept = settings.to_h.stringify_keys.slice(*SETTINGS.fetch(kind.to_s, [])).compact_blank
    self.settings = DEFAULTS.fetch(kind.to_s, {}).merge(kept).to_h do |key, value|
      [key, INTEGER_SETTINGS.include?(key) ? Integer(value.to_s, 10, exception: false) || value : value.to_s.strip]
    end
    self.expected_statuses = expected_statuses.delete(" ") if expected_statuses.is_a?(String)
  end

  def remember_environment
    self.environment_required = environment_id.present? if will_save_change_to_environment_id?
  end

  def bump_config_version
    self.config_version += 1 if changed.intersect?(CONFIG_ATTRIBUTES)
  end

  def interval_of_kind
    errors.add(:interval, :inclusion) unless intervals.include?(interval)
  end

  def settings_of_kind
    case kind
    when "http" then http_settings
    when "tcp" then host_settings
    when "ssl" then host_settings && number_setting(:days_before, 1..90)
    when "domain" then host_present && number_setting(:days_before, 1..365)
    when "push" then number_setting(:grace, 0..86_400) && push_token_present
    end
  end

  def http_settings
    return errors.add(:mode, :inclusion) unless MODES.include?(mode)

    if mode == "url"
      errors.add(:url, :blank) if url.blank?
      errors.add(:url, :too_long, count: MAX_URL_LENGTH) if url.to_s.length > MAX_URL_LENGTH
      errors.add(:http_method, :inclusion) unless HTTP_METHODS.include?(http_method)
    else
      errors.add(:api_request, :blank) unless api_request
    end
    errors.add(:expected_statuses, :invalid) unless valid_statuses?
    number_setting(:max_response_ms, 1..60_000, optional: true)
  end

  def push_token_present
    errors.add(:base, :push_token) if push_token_digest.blank?
  end

  def host_settings
    host_present && number_setting(:port, 1..65_535)
  end

  def host_present
    errors.add(:host, :blank) if host.blank?
    errors.add(:host, :too_long, count: MAX_HOST_LENGTH) if host.to_s.length > MAX_HOST_LENGTH
    errors.exclude?(:host)
  end

  def number_setting(name, range, optional: false)
    value = public_send(name)
    return true if optional && value.nil?

    errors.add(name, :inclusion) unless value.is_a?(Integer) && range.cover?(value)
    errors.exclude?(name)
  end

  def valid_statuses?
    return false unless expected_statuses.to_s.match?(STATUS_LIST)

    expected_statuses.split(",").all? do |part|
      first, last = part.split("-").map(&:to_i)
      (100..599).cover?(first) && (last.nil? || (first..599).cover?(last))
    end
  end

  def references_in_project
    errors.add(:environment, :invalid) if environment && environment.project_id != project_id
    errors.add(:api_request, :invalid) if api_request && api_request.project_id != project_id
  end

  def kind_unchanged
    errors.add(:kind, :immutable) if kind_changed?
  end

  def channels_within_limit
    errors.add(:notification_channels, :too_many, count: MonitorChannel::PER_MONITOR) if notification_channels.size > MonitorChannel::PER_MONITOR
  end

  def within_limits
    return unless project

    errors.add(:base, :project_limit, count: self.class.per_project_limit) if project.uptime_monitors.count >= self.class.per_project_limit
    errors.add(:base, :total_limit, count: self.class.total_limit) if self.class.total_limit && self.class.count >= self.class.total_limit
  end
end
