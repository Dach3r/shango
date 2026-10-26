class ChangeCollectionIdNullOnApiRequests < ActiveRecord::Migration[8.1]
  def change
    change_column_null :api_requests, :collection_id, true
  end
end
