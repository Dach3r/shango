class CreateRequestTabs < ActiveRecord::Migration[8.1]
  def change
    create_table :request_tabs, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :api_request, type: :uuid, null: false, foreign_key: { on_delete: :cascade }

      t.timestamps
    end

    add_index :request_tabs, %i[user_id api_request_id], unique: true
  end
end
