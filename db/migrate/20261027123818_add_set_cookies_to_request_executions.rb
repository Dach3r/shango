class AddSetCookiesToRequestExecutions < ActiveRecord::Migration[8.1]
  def change
    add_column :request_executions, :set_cookies, :jsonb, default: [], null: false
  end
end
