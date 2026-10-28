class CreateCollectionExports < ActiveRecord::Migration[8.1]
  def change
    create_table :collection_exports, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :collection, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.string :export_format, null: false
      t.boolean :include_environments, null: false, default: false
      t.boolean :include_credentials, null: false, default: false
      t.string :status, null: false, default: "queued"
      t.integer :progress, null: false, default: 0
      t.string :error
      t.string :filename
      t.string :content_type
      t.text :content
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_check_constraint :collection_exports, "export_format IN ('postman', 'insomnia', 'openapi', 'shango')", name: "collection_exports_export_format_check"
    add_check_constraint :collection_exports, "status IN ('queued', 'running', 'done', 'failed')", name: "collection_exports_status_check"
    add_index :collection_exports, :expires_at
  end
end
