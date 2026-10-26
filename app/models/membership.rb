class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :project
  belongs_to :current_environment, class_name: "Environment", optional: true, inverse_of: :memberships

  FOLDER_TOGGLES = { click: "click", double_click: "double_click" }.freeze

  enum :role, { member: "member", owner: "owner" }, default: "member"
  enum :folder_toggle, FOLDER_TOGGLES, default: "double_click", prefix: true

  scope :active, -> { where(revoked_at: nil) }

  validates :user_id, uniqueness: { scope: :project_id, conditions: -> { active } }

  def active?
    revoked_at.nil?
  end

  def revoke!
    update!(revoked_at: Time.current)
  end
end
