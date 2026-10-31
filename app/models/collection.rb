class Collection < ApplicationRecord
  include Positionable
  include AuthConfigurable
  include TestAutomation

  belongs_to :project
  belongs_to :creator, class_name: "User", optional: true

  has_many :folders, dependent: :destroy
  has_many :api_requests, dependent: :destroy
  has_many :collection_runs, dependent: :delete_all

  validates :name, presence: true

  scope :ordered, -> { order(:position, :created_at) }

  def siblings
    project.collections
  end
end
