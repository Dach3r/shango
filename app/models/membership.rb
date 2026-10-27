class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :project
  belongs_to :current_environment, class_name: "Environment", optional: true, inverse_of: :memberships

  CLICK_MODES = { click: "click", double_click: "double_click" }.freeze
  COLOR_SCHEMES = { system: "system", light: "light", dark: "dark" }.freeze
  THEMES = %w[default blue green yellow red ocean purple rose orange forest midnight nord dracula gruvbox solarized sunset coffee cyberpunk mono graphite].to_h { |theme| [theme.to_sym, theme] }.freeze

  enum :role, { member: "member", owner: "owner" }, default: "member"
  enum :folder_toggle, CLICK_MODES, default: "double_click", prefix: true, validate: true
  enum :request_open, CLICK_MODES, default: "click", prefix: true, validate: true
  enum :color_scheme, COLOR_SCHEMES, default: "system", prefix: true, validate: true
  enum :theme, THEMES, default: "default", prefix: true, validate: true

  scope :active, -> { where(revoked_at: nil) }

  validates :user_id, uniqueness: { scope: :project_id, conditions: -> { active } }

  def active?
    revoked_at.nil?
  end

  def revoke!
    update!(revoked_at: Time.current)
  end
end
