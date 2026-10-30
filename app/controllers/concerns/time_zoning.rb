module TimeZoning
  extend ActiveSupport::Concern

  included do
    around_action :use_time_zone
  end

  private

  # Signed-in users see times in their own zone; everyone else gets the app default (UTC).
  def use_time_zone(&)
    zone = request.env["warden"].user(:user)&.time_zone
    Time.use_zone(zone || Time.zone, &)
  end
end
