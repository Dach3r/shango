class Project < ApplicationRecord
  ICONS = %w[
    rocket zap flask-conical hammer package globe flame puzzle
    folder code terminal database server cloud git-branch bug cpu lock key shield
    star heart bookmark flag bell mail message-square users user briefcase building home
    layers layout-dashboard palette pen-tool image camera music video gamepad-2
    book-open graduation-cap lightbulb target trophy gift shopping-cart credit-card wallet
    chart-bar chart-line chart-pie calendar clock map map-pin compass plane car bike truck
    wrench settings sliders-horizontal cog anchor leaf sun moon snowflake droplet wind
    mountain tree-pine coffee pizza apple smartphone laptop monitor wifi bot brain sparkles
    wand-sparkles atom microscope dna test-tube box boxes archive link share-2 globe-lock
    fingerprint scan-line qr-code store factory hospital school landmark newspaper file-text
    notebook pencil
  ].freeze

  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships

  scope :active, -> { where(archived_at: nil) }

  validates :name, presence: true
  validates :icon, presence: true, inclusion: { in: ICONS, allow_blank: true }

  def self.create_with_owner(user, attributes)
    project = new(attributes)

    transaction do
      project.save!
      project.memberships.create!(user:, role: :owner)
    end

    project
  rescue ActiveRecord::RecordInvalid
    project
  end
end
