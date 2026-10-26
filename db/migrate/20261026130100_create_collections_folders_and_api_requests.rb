class CreateCollectionsFoldersAndApiRequests < ActiveRecord::Migration[8.1]
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

    create_table :folders, id: :uuid do |t|
      t.references :collection, type: :uuid, null: false, foreign_key: true
      t.references :parent, type: :uuid, null: true, foreign_key: { to_table: :folders }
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.string :auth_type, null: false, default: "inherit"
      t.text :auth_config

      t.timestamps
    end

    create_table :api_requests, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true
      t.references :collection, type: :uuid, null: false, foreign_key: true
      t.references :folder, type: :uuid, null: true, foreign_key: true
      t.string :name, null: false
      t.string :http_method, null: false, default: "GET"
      t.text :url, null: false, default: ""
      t.integer :position, null: false, default: 0
      t.jsonb :query_params, null: false, default: []
      t.jsonb :headers, null: false, default: []
      t.string :body_type, null: false, default: "none"
      t.text :body
      t.jsonb :body_form, null: false, default: []
      t.text :graphql_variables
      t.string :auth_type, null: false, default: "inherit"
      t.text :auth_config
      t.jsonb :settings, null: false, default: {}
      t.text :description

      t.timestamps
    end

    create_table :request_executions, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true
      t.references :api_request, type: :uuid, null: false, foreign_key: true
      t.references :user, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.references :environment, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.string :http_method, null: false
      t.text :url, null: false
      t.integer :status
      t.string :status_text
      t.integer :duration_ms
      t.bigint :size_bytes, null: false, default: 0
      t.jsonb :request_headers, null: false, default: []
      t.text :request_body
      t.jsonb :response_headers, null: false, default: []
      t.text :response_body
      t.string :content_type
      t.boolean :body_truncated, null: false, default: false
      t.boolean :body_omitted, null: false, default: false
      t.jsonb :redirects, null: false, default: []
      t.jsonb :unresolved_variables, null: false, default: []
      t.string :error_kind
      t.text :error_message

      t.datetime :created_at, null: false
    end

    add_index :request_executions, %i[api_request_id created_at]
  end
end
