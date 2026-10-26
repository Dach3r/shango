module Serviceable
  extend ActiveSupport::Concern

  included do
    def self.call(**kwargs)
      new(**kwargs).send(:perform)
    end
  end

  private

  def perform
    raise NotImplementedError, "#{self.class} must implement #perform method"
  end
end
