class AddCreatorToCollections < ActiveRecord::Migration[8.1]
  def change
    add_reference :collections, :creator, type: :uuid, null: true, foreign_key: { to_table: :users, on_delete: :nullify }
  end
end
