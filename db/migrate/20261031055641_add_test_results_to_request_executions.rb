class AddTestResultsToRequestExecutions < ActiveRecord::Migration[8.1]
  def change
    add_column :request_executions, :test_results, :jsonb, default: [], null: false
  end
end
