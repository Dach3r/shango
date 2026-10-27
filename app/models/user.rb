class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable, :trackable, :confirmable, :lockable, :timeoutable

  belongs_to :current_membership, class_name: "Membership", optional: true

  has_many :memberships, dependent: :destroy
  has_many :api_requests, dependent: :destroy
  has_many :request_tabs, dependent: :destroy
  has_many :projects, -> { merge(Membership.active) }, through: :memberships

  validates :first_name, :last_name, presence: true
  validates :password_confirmation, presence: true, if: -> { persisted? && password.present? }

  # Confirmation needs working email; without SMTP (or when the operator opts out) accounts are active right away.
  def confirmation_required?
    Shango::Mailing.confirmation_required? && !confirmed?
  end

  # Email changes only wait for confirmation when confirmation is enforced.
  def postpone_email_change?
    super && Shango::Mailing.confirmation_required?
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def initials
    "#{first_name[0]}#{last_name[0]}".upcase
  end

  def available_memberships
    memberships.active.joins(:project).merge(Project.active)
  end
end
