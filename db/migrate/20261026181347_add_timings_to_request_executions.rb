class AddTimingsToRequestExecutions < ActiveRecord::Migration[8.1]
  def change
    add_column :request_executions, :timings, :jsonb, default: {}, null: false
  end
end
