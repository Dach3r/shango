class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :project

  enum :role, { member: "member", owner: "owner" }, default: "member"

  validates :user_id, uniqueness: { scope: :project_id }
end
