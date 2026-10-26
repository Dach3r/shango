# Orders a record among its siblings. Including models define `siblings`.
module Positionable
  extend ActiveSupport::Concern

  included do
    before_create :append_to_siblings
  end

  private

  def append_to_siblings
    self.position = siblings.maximum(:position).to_i + 1 if position.to_i.zero?
  end
end
