# Where a project's monitors send their alerts: email addresses or a webhook URL. The target and the signing secret
# carry credentials (a webhook URL is often its own secret), so both are encrypted and only rendered masked. Messages
# are written in the channel's `locale`. The kind cannot change after creation.
class NotificationChannel < ApplicationRecord
  PER_PROJECT = 20
  MAX_ADDRESSES = 10
  MAX_URL_LENGTH = 2048
  SEPARATORS = /[\s,;]+/

  belongs_to :project
  belongs_to :creator, class_name: "User", optional: true

  has_many :monitor_channels, dependent: :delete_all
  has_many :uptime_monitors, through: :monitor_channels
  has_many :deliveries, class_name: "NotificationDelivery", dependent: :delete_all

  enum :kind, { email: "email", webhook: "webhook" }, validate: true

  encrypts :target, :signing_secret

  scope :ordered, -> { order(:name, :id) }

  before_validation :normalize_target
  before_create :regenerate_signing_secret, if: :webhook?

  validates :name, presence: true, length: { maximum: 100 }
  validates :locale, inclusion: { in: ->(_) { I18n.available_locales.map(&:to_s) } }
  validate :target_of_kind
  validate :kind_unchanged, on: :update
  validate :within_limit, on: :create

  def addresses
    email? ? target.to_s.split(SEPARATORS).compact_blank : []
  end

  def uri
    URI.parse(target.to_s) unless email?
  rescue URI::Error
    nil
  end

  # What the page shows of the target: the addresses, or the URL cut to its scheme, host and last four characters.
  def masked_target
    return addresses.join(", ") if email?

    "#{uri&.scheme}://#{uri&.host}/…#{target.to_s.last(4)}"
  end

  def regenerate_signing_secret
    self.signing_secret = "whsec_#{SecureRandom.urlsafe_base64(32)}"
  end

  private

  def normalize_target
    self.target = email? ? addresses.uniq.join(", ") : target.to_s.strip
  end

  def target_of_kind
    email? ? email_target : url_target
  end

  def email_target
    errors.add(:target, :blank) if addresses.empty?
    errors.add(:target, :too_many_addresses, count: MAX_ADDRESSES) if addresses.size > MAX_ADDRESSES
    errors.add(:target, :invalid_address, address: addresses.find { |address| !address.match?(URI::MailTo::EMAIL_REGEXP) }) unless addresses.all? { |address| address.match?(URI::MailTo::EMAIL_REGEXP) }
  end

  def url_target
    return errors.add(:target, :blank) if target.blank?
    return errors.add(:target, :too_long, count: MAX_URL_LENGTH) if target.length > MAX_URL_LENGTH

    errors.add(:target, :invalid_url) unless uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil?
  end

  def kind_unchanged
    errors.add(:kind, :immutable) if kind_changed?
  end

  def within_limit
    errors.add(:base, :project_limit, count: PER_PROJECT) if project && project.notification_channels.count >= PER_PROJECT
  end
end
