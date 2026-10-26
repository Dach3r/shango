class CreateApiRequests < ActiveRecord::Migration[8.1]
  def change
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

      t.check_constraint "http_method IN ('GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS')", name: "api_requests_http_method_check"
      t.check_constraint "body_type IN ('none', 'json', 'text', 'xml', 'form_urlencoded', 'multipart', 'graphql', 'binary')", name: "api_requests_body_type_check"
    end
  end
end
