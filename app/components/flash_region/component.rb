class FlashRegion::Component < ApplicationComponent
  # Flash keys rendered as flash messages; Devise uses :notice and :alert.
  def initialize(flash:)
    @flash = flash
  end

  private

  def messages
    @flash.to_h.filter_map do |kind, message|
      [kind.to_sym, message] if message.is_a?(String) && message.present?
    end
  end
end
