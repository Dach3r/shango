class AddScriptLogsToRequestExecutions < ActiveRecord::Migration[8.1]
  def change
    add_column :request_executions, :script_logs, :jsonb, default: [], null: false
  end
end
