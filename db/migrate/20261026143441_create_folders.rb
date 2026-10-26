class CreateFolders < ActiveRecord::Migration[8.1]
  def change
    create_table :folders, id: :uuid do |t|
      t.references :collection, type: :uuid, null: false, foreign_key: true
      t.references :parent, type: :uuid, null: true, foreign_key: { to_table: :folders }
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.string :auth_type, null: false, default: "inherit"
      t.text :auth_config

      t.timestamps
    end
  end
end
