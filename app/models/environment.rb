class Environment < ApplicationRecord
  include Positionable

  belongs_to :project

  has_many :variables, -> { order(:position, :created_at) }, dependent: :destroy, inverse_of: :environment
  has_many :cookies, dependent: :destroy
  has_many :memberships, foreign_key: :current_environment_id, dependent: :nullify, inverse_of: :current_environment

  accepts_nested_attributes_for :variables, allow_destroy: true, reject_if: ->(attributes) { attributes[:key].blank? && attributes[:value].blank? }

  validates :name, presence: true, uniqueness: { scope: :project_id, case_sensitive: false }

  validate :variable_keys_unique

  scope :ordered, -> { order(:position, :created_at) }

  def siblings
    project.environments
  end

  def variable_values
    variables.select(&:enabled).to_h { |variable| [variable.key, variable.value.to_s] }
  end

  def secret_values
    variables.select { |variable| variable.enabled && variable.secret && variable.value.present? }.map(&:value)
  end

  private

  # The unique index would reject duplicates inside one submission with a 500; the per-row uniqueness check only sees saved rows.
  def variable_keys_unique
    keys = variables.reject(&:marked_for_destruction?).filter_map { |variable| variable.key.presence }
    errors.add(:base, :duplicated_variable_keys) if keys.uniq.size < keys.size
  end
end
