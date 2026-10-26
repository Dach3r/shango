class Collection < ApplicationRecord
  include Positionable
  include AuthConfigurable

  belongs_to :project

  has_many :folders, dependent: :destroy
  has_many :api_requests, dependent: :destroy

  validates :name, presence: true

  scope :ordered, -> { order(:position, :created_at) }

  def siblings
    project.collections
  end
end
