class Folder < ApplicationRecord
  include Positionable
  include AuthConfigurable

  belongs_to :collection
  belongs_to :parent, class_name: "Folder", optional: true, inverse_of: :children
  has_many :children, class_name: "Folder", foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent
  has_many :api_requests, dependent: :destroy

  validates :name, presence: true
  validate :parent_belongs_to_collection
  validate :parent_is_not_self_or_descendant

  def siblings
    collection.folders.where(parent_id:)
  end

  def allowed_auth_types
    [AuthConfigurable::INHERIT, *super]
  end

  # Parents from the nearest one up to the root folder.
  def ancestors
    chain = []
    node = parent
    while node && chain.exclude?(node)
      chain << node
      node = node.parent
    end
    chain
  end

  def descendant_of?(folder)
    ancestors.include?(folder)
  end

  private

  def parent_belongs_to_collection
    errors.add(:parent, :invalid) if parent && parent.collection_id != collection_id
  end

  def parent_is_not_self_or_descendant
    return unless parent

    errors.add(:parent, :invalid) if parent == self || parent.descendant_of?(self)
  end
end
