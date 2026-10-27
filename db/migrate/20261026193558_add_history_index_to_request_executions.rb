class AddHistoryIndexToRequestExecutions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :request_executions, %i[project_id user_id created_at], name: "index_request_executions_on_project_user_and_created_at", algorithm: :concurrently
  end
end
