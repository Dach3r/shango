class CreateEnvironments < ActiveRecord::Migration[8.1]
  def change
    create_table :environments, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :environments, %i[project_id name], unique: true

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

    add_reference :memberships, :current_environment, type: :uuid, null: true, foreign_key: { to_table: :environments, on_delete: :nullify }
  end
end
