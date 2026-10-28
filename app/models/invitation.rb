# An owner's invitation for an email address to join a project. The token is only ever known by whoever receives the
# link: just its digest is stored.
class Invitation < ApplicationRecord
  VALID_FOR = 7.days

  belongs_to :project
  belongs_to :inviter, class_name: "User", optional: true

  enum :role, { member: "member", owner: "owner" }, default: "member", validate: true

  attr_reader :token

  before_validation :normalize_email
  before_validation :issue_token, on: :create

  validates :email, presence: true, length: { maximum: 254 }, format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
  validates :expires_at, presence: true

  scope :open, -> { where(accepted_at: nil, revoked_at: nil) }

  class << self
    def digest(token)
      Digest::SHA256.hexdigest(token.to_s)
    end

    def find_by_token(token)
      find_by(token_digest: digest(token)) if token.present?
    end
  end

  def accepted?
    accepted_at.present?
  end

  def revoked?
    revoked_at.present?
  end

  def expired?
    expires_at <= Time.current
  end

  def usable?
    !accepted? && !revoked? && !expired?
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end

  def issue_token
    @token = SecureRandom.urlsafe_base64(32)
    self.token_digest = self.class.digest(@token)
    self.expires_at ||= VALID_FOR.from_now
  end
end
