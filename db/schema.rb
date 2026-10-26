# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_26_163512) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "uuid-ossp"

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.uuid "record_id", null: false
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "api_requests", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "project_id", null: false
    t.uuid "collection_id"
    t.uuid "folder_id"
    t.string "name", null: false
    t.string "http_method", default: "GET", null: false
    t.text "url", default: "", null: false
    t.integer "position", default: 0, null: false
    t.jsonb "query_params", default: [], null: false
    t.jsonb "headers", default: [], null: false
    t.string "body_type", default: "none", null: false
    t.text "body"
    t.jsonb "body_form", default: [], null: false
    t.text "graphql_variables"
    t.string "auth_type", default: "inherit", null: false
    t.text "auth_config"
    t.jsonb "settings", default: {}, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id"
    t.index ["collection_id"], name: "index_api_requests_on_collection_id"
    t.index ["folder_id"], name: "index_api_requests_on_folder_id"
    t.index ["project_id"], name: "index_api_requests_on_project_id"
    t.index ["user_id"], name: "index_api_requests_on_user_id"
    t.check_constraint "body_type::text = ANY (ARRAY['none'::character varying, 'json'::character varying, 'text'::character varying, 'xml'::character varying, 'form_urlencoded'::character varying, 'multipart'::character varying, 'graphql'::character varying, 'binary'::character varying]::text[])", name: "api_requests_body_type_check"
    t.check_constraint "collection_id IS NOT NULL OR user_id IS NOT NULL AND folder_id IS NULL", name: "api_requests_draft_check"
    t.check_constraint "http_method::text = ANY (ARRAY['GET'::character varying, 'POST'::character varying, 'PUT'::character varying, 'PATCH'::character varying, 'DELETE'::character varying, 'HEAD'::character varying, 'OPTIONS'::character varying]::text[])", name: "api_requests_http_method_check"
  end

  create_table "collections", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "project_id", null: false
    t.string "name", null: false
    t.text "description"
    t.integer "position", default: 0, null: false
    t.string "auth_type", default: "none", null: false
    t.text "auth_config"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_collections_on_project_id"
  end

  create_table "environments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "project_id", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "name"], name: "index_environments_on_project_id_and_name", unique: true
    t.index ["project_id"], name: "index_environments_on_project_id"
  end

  create_table "folders", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "collection_id", null: false
    t.uuid "parent_id"
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.string "auth_type", default: "inherit", null: false
    t.text "auth_config"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["collection_id"], name: "index_folders_on_collection_id"
    t.index ["parent_id"], name: "index_folders_on_parent_id"
  end

  create_table "memberships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "role", default: "member", null: false
    t.uuid "project_id", null: false
    t.uuid "user_id", null: false
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "current_environment_id"
    t.string "folder_toggle", default: "double_click", null: false
    t.index ["current_environment_id"], name: "index_memberships_on_current_environment_id"
    t.index ["project_id"], name: "index_memberships_on_project_id"
    t.index ["user_id", "project_id"], name: "index_memberships_on_user_id_and_project_id", unique: true, where: "(revoked_at IS NULL)"
    t.check_constraint "folder_toggle::text = ANY (ARRAY['click'::character varying, 'double_click'::character varying]::text[])", name: "memberships_folder_toggle_check"
  end

  create_table "projects", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "icon", null: false
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_projects_on_name"
  end

  create_table "request_executions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "project_id", null: false
    t.uuid "api_request_id", null: false
    t.uuid "user_id"
    t.uuid "environment_id"
    t.string "http_method", null: false
    t.text "url", null: false
    t.integer "status"
    t.string "status_text"
    t.integer "duration_ms"
    t.bigint "size_bytes", default: 0, null: false
    t.jsonb "request_headers", default: [], null: false
    t.text "request_body"
    t.jsonb "response_headers", default: [], null: false
    t.text "response_body"
    t.string "content_type"
    t.boolean "body_truncated", default: false, null: false
    t.boolean "body_omitted", default: false, null: false
    t.jsonb "redirects", default: [], null: false
    t.jsonb "unresolved_variables", default: [], null: false
    t.string "error_kind"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.index ["api_request_id", "created_at"], name: "index_request_executions_on_api_request_id_and_created_at"
    t.index ["api_request_id"], name: "index_request_executions_on_api_request_id"
    t.index ["environment_id"], name: "index_request_executions_on_environment_id"
    t.index ["project_id"], name: "index_request_executions_on_project_id"
    t.index ["user_id"], name: "index_request_executions_on_user_id"
  end

  create_table "request_tabs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "api_request_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["api_request_id"], name: "index_request_tabs_on_api_request_id"
    t.index ["user_id", "api_request_id"], name: "index_request_tabs_on_user_id_and_api_request_id", unique: true
    t.index ["user_id"], name: "index_request_tabs_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "current_membership_id"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["current_membership_id"], name: "index_users_on_current_membership_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  create_table "variables", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "environment_id", null: false
    t.string "key", null: false
    t.text "value"
    t.boolean "secret", default: false, null: false
    t.boolean "enabled", default: true, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["environment_id", "key"], name: "index_variables_on_environment_id_and_key", unique: true
    t.index ["environment_id"], name: "index_variables_on_environment_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "api_requests", "collections"
  add_foreign_key "api_requests", "folders"
  add_foreign_key "api_requests", "projects"
  add_foreign_key "api_requests", "users", on_delete: :cascade
  add_foreign_key "collections", "projects"
  add_foreign_key "environments", "projects"
  add_foreign_key "folders", "collections"
  add_foreign_key "folders", "folders", column: "parent_id"
  add_foreign_key "memberships", "environments", column: "current_environment_id", on_delete: :nullify
  add_foreign_key "memberships", "projects"
  add_foreign_key "memberships", "users"
  add_foreign_key "request_executions", "api_requests"
  add_foreign_key "request_executions", "environments", on_delete: :nullify
  add_foreign_key "request_executions", "projects"
  add_foreign_key "request_executions", "users", on_delete: :nullify
  add_foreign_key "request_tabs", "api_requests", on_delete: :cascade
  add_foreign_key "request_tabs", "users", on_delete: :cascade
  add_foreign_key "users", "memberships", column: "current_membership_id", on_delete: :nullify
  add_foreign_key "variables", "environments"
end
