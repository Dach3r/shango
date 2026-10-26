class CreateVariables < ActiveRecord::Migration[8.1]
  def change
    create_table :variables, id: :uuid do |t|
      t.references :environment, type: :uuid, null: false, foreign_key: true
      t.string :key, null: false
      t.text :value
      t.boolean :secret, null: false, default: false
      t.boolean :enabled, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :variables, %i[environment_id key], unique: true
  end
end
