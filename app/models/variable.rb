class Variable < ApplicationRecord
  KEY_FORMAT = /\A[A-Za-z_][\w.\-]*\z/

  belongs_to :environment, inverse_of: :variables

  encrypts :value

  validates :key, presence: true, format: { with: KEY_FORMAT, allow_blank: true }, uniqueness: { scope: :environment_id }

  # Secrets never leave the server: the browser only gets the mask.
  def masked_value
    secret && value.present? ? ApiClient::Masker::MASK : value.to_s
  end

  def value=(new_value)
    return if persisted? && secret && new_value.blank?

    super
  end
end
