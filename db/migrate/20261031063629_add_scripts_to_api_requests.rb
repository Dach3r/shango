class AddScriptsToApiRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :api_requests, :pre_request_script, :text
    add_column :api_requests, :post_response_script, :text
  end
end
