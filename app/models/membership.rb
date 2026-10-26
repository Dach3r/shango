class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :project
  belongs_to :current_environment, class_name: "Environment", optional: true, inverse_of: :memberships

  CLICK_MODES = { click: "click", double_click: "double_click" }.freeze

  enum :role, { member: "member", owner: "owner" }, default: "member"
  enum :folder_toggle, CLICK_MODES, default: "double_click", prefix: true
  enum :request_open, CLICK_MODES, default: "click", prefix: true

  scope :active, -> { where(revoked_at: nil) }

  validates :user_id, uniqueness: { scope: :project_id, conditions: -> { active } }

  def active?
    revoked_at.nil?
  end

  def revoke!
    update!(revoked_at: Time.current)
  end
end
