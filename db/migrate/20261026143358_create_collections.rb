class CreateCollections < ActiveRecord::Migration[8.1]
  def change
    create_table :collections, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.integer :position, null: false, default: 0
      t.string :auth_type, null: false, default: "none"
      t.text :auth_config

      t.timestamps
    end
  end
end
