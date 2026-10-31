class AddAssertionsAndExtractorsToApiRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :api_requests, :assertions, :jsonb, default: [], null: false
    add_column :api_requests, :extractors, :jsonb, default: [], null: false
  end
end
