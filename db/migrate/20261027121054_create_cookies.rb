class CreateCookies < ActiveRecord::Migration[8.1]
  def change
    create_table :cookies, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true
      t.references :environment, type: :uuid, foreign_key: true
      t.string :domain, null: false
      t.string :path, null: false, default: "/"
      t.string :name, null: false
      t.text :value
      t.boolean :host_only, null: false, default: true
      t.boolean :secure, null: false, default: false
      t.boolean :http_only, null: false, default: false
      t.datetime :expires_at

      t.timestamps
    end

    add_index :cookies, %i[project_id environment_id domain path name], unique: true, nulls_not_distinct: true, name: "index_cookies_on_jar_and_identity"
  end
end
