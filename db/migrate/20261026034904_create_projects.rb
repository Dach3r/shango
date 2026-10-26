class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects, id: :uuid do |t|
      t.string :name, null: false
      t.string :icon, null: false
      t.datetime :archived_at, null: true

      t.timestamps
    end

    add_index :projects, :name
  end
end
