class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable, :trackable

  belongs_to :current_membership, class_name: "Membership", optional: true

  has_many :memberships, dependent: :destroy
  has_many :projects, -> { merge(Membership.active) }, through: :memberships

  validates :first_name, :last_name, presence: true
  validates :password_confirmation, presence: true, if: -> { persisted? && password.present? }

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
