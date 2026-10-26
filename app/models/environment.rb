class Environment < ApplicationRecord
  include Positionable

  belongs_to :project
  has_many :variables, -> { order(:position, :created_at) }, dependent: :destroy, inverse_of: :environment
  has_many :memberships, foreign_key: :current_environment_id, dependent: :nullify, inverse_of: :current_environment

  accepts_nested_attributes_for :variables, allow_destroy: true, reject_if: ->(attributes) { attributes[:key].blank? && attributes[:value].blank? }

  validates :name, presence: true, uniqueness: { scope: :project_id, case_sensitive: false }

  scope :ordered, -> { order(:position, :created_at) }

  def siblings
    project.environments
  end

  # Enabled variables as name => value, ready for interpolation.
  def variable_values
    variables.select(&:enabled).to_h { |variable| [variable.key, variable.value.to_s] }
  end

  def secret_values
    variables.select { |variable| variable.enabled && variable.secret && variable.value.present? }.map(&:value)
  end
end
