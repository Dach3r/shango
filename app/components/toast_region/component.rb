class ToastRegion::Component < ApplicationComponent
  # Flash keys rendered as toasts; Devise uses :notice and :alert.
  def initialize(flash:)
    @flash = flash
  end

  private

  def toasts
    @flash.to_h.filter_map do |kind, message|
      [kind.to_sym, message] if message.is_a?(String) && message.present?
    end
  end
end
