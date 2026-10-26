class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :project

  enum :role, { member: "member", owner: "owner" }, default: "member"

  scope :active, -> { where(revoked_at: nil) }

  validates :user_id, uniqueness: { scope: :project_id, conditions: -> { active } }

  def active?
    revoked_at.nil?
  end

  def revoke!
    update!(revoked_at: Time.current)
  end
end
