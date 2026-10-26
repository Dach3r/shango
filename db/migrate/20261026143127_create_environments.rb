class CreateEnvironments < ActiveRecord::Migration[8.1]
  def change
    create_table :environments, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :environments, %i[project_id name], unique: true
  end
end
