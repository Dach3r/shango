class Project < ApplicationRecord
  ICONS = LucideRails::GEM_ROOT.join("icons", "stripped").glob("*.svg").map { |file| file.basename(".svg").to_s }.sort.freeze

  has_many :memberships, dependent: :destroy
  has_many :users, -> { merge(Membership.active) }, through: :memberships
  has_many :environments, dependent: :destroy
  has_many :cookies, dependent: :destroy
  has_many :collections, dependent: :destroy
  has_many :folders, through: :collections
  has_many :api_requests, dependent: :destroy
  has_many :request_executions, dependent: :destroy

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
