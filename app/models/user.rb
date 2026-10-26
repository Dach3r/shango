class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable, :trackable

  has_many :memberships, dependent: :destroy
  has_many :projects, through: :memberships

  validates :first_name, :last_name, presence: true
  validates :password_confirmation, presence: true, if: -> { persisted? && password.present? }
end
