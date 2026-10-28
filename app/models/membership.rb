class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :project
  belongs_to :current_environment, class_name: "Environment", optional: true, inverse_of: :memberships

  CLICK_MODES = { click: "click", double_click: "double_click" }.freeze
  COLOR_SCHEMES = { system: "system", light: "light", dark: "dark" }.freeze
  ACCENT_THEMES = %w[default blue green yellow red purple rose orange mono].freeze
  STYLE_THEMES = %w[ocean forest midnight nord dracula gruvbox solarized sunset coffee cyberpunk graphite].freeze
  OMARCHY_CREDITS = YAML.load_file(Rails.root.join("config/omarchy_themes.yml")).map(&:with_indifferent_access).freeze
  OMARCHY_THEMES = OMARCHY_CREDITS.pluck(:key).freeze
  OMARCHY_SCHEMES = OMARCHY_CREDITS.to_h { |credit| [credit[:key], credit[:scheme]] }.freeze
  THEMES = (ACCENT_THEMES + STYLE_THEMES + OMARCHY_THEMES).to_h { |theme| [theme.to_sym, theme] }.freeze

  enum :role, { member: "member", owner: "owner" }, default: "member"
  enum :folder_toggle, CLICK_MODES, default: "double_click", prefix: true, validate: true
  enum :request_open, CLICK_MODES, default: "click", prefix: true, validate: true
  enum :color_scheme, COLOR_SCHEMES, default: "system", prefix: true, validate: true
  enum :theme, THEMES, default: "mono", prefix: true, validate: true

  scope :active, -> { where(revoked_at: nil) }

  validates :user_id, uniqueness: { scope: :project_id, conditions: -> { active } }
  validate :project_keeps_an_owner, on: :update

  # Omarchy themes pin their own color scheme; every other theme follows the member's choice.
  def self.pinned_scheme(theme)
    OMARCHY_SCHEMES[theme.to_s]
  end

  def active?
    revoked_at.nil?
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  private

  # A project always keeps at least one active owner: the last one can neither lose the role nor leave.
  def project_keeps_an_owner
    return unless role_in_database == "owner" && revoked_at_in_database.nil?
    return unless !owner? || revoked_at.present?
    return if project.memberships.active.owner.where.not(id:).exists?

    errors.add(:base, :last_owner)
  end
end
