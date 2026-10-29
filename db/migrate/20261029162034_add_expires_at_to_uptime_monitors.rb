class AddExpiresAtToUptimeMonitors < ActiveRecord::Migration[8.1]
  def change
    add_column :uptime_monitors, :expires_at, :datetime
  end
end
