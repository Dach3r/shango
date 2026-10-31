class AddAssertionsAndExtractorsToCollections < ActiveRecord::Migration[8.1]
  def change
    add_column :collections, :assertions, :jsonb, default: [], null: false
    add_column :collections, :extractors, :jsonb, default: [], null: false
  end
end
