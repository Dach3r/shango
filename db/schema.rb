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

ActiveRecord::Schema[8.1].define(version: 2026_10_27_223651) do
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
    t.index ["project_id", "collection_id", "folder_id", "position"], name: "index_api_requests_on_tree_order"
    t.index ["project_id", "user_id"], name: "index_api_requests_on_drafts", where: "(collection_id IS NULL)"
    t.index ["project_id"], name: "index_api_requests_on_project_id"
    t.index ["user_id"], name: "index_api_requests_on_user_id"
    t.check_constraint "body_type::text = ANY (ARRAY['none'::character varying::text, 'json'::character varying::text, 'text'::character varying::text, 'xml'::character varying::text, 'form_urlencoded'::character varying::text, 'multipart'::character varying::text, 'graphql'::character varying::text, 'binary'::character varying::text])", name: "api_requests_body_type_check"
    t.check_constraint "collection_id IS NOT NULL OR user_id IS NOT NULL AND folder_id IS NULL", name: "api_requests_draft_check"
    t.check_constraint "http_method::text = ANY (ARRAY['GET'::character varying::text, 'POST'::character varying::text, 'PUT'::character varying::text, 'PATCH'::character varying::text, 'DELETE'::character varying::text, 'HEAD'::character varying::text, 'OPTIONS'::character varying::text])", name: "api_requests_http_method_check"
  end

  create_table "audit_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "project_id", null: false
    t.uuid "actor_id"
    t.uuid "target_id"
    t.string "kind", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.index ["actor_id"], name: "index_audit_events_on_actor_id"
    t.index ["project_id", "created_at"], name: "index_audit_events_on_project_id_and_created_at"
    t.index ["target_id"], name: "index_audit_events_on_target_id"
    t.check_constraint "kind::text = ANY (ARRAY['member_invited'::character varying, 'invitation_accepted'::character varying, 'invitation_revoked'::character varying, 'role_changed'::character varying, 'member_revoked'::character varying, 'member_left'::character varying, 'ownership_transferred'::character varying]::text[])", name: "audit_events_kind_check"
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
    t.uuid "creator_id"
    t.index ["creator_id"], name: "index_collections_on_creator_id"
    t.index ["project_id"], name: "index_collections_on_project_id"
  end

  create_table "cookies", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "project_id", null: false
    t.uuid "environment_id"
    t.string "domain", null: false
    t.string "path", default: "/", null: false
    t.string "name", null: false
    t.text "value"
    t.boolean "host_only", default: true, null: false
    t.boolean "secure", default: false, null: false
    t.boolean "http_only", default: false, null: false
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["environment_id"], name: "index_cookies_on_environment_id"
    t.index ["project_id", "environment_id", "domain", "path", "name"], name: "index_cookies_on_jar_and_identity", unique: true, nulls_not_distinct: true
    t.index ["project_id"], name: "index_cookies_on_project_id"
  end

  create_table "environments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "project_id", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "creator_id"
    t.index ["creator_id"], name: "index_environments_on_creator_id"
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

  create_table "invitations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "project_id", null: false
    t.uuid "inviter_id"
    t.string "email", null: false
    t.string "role", default: "member", null: false
    t.string "token_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "accepted_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["inviter_id"], name: "index_invitations_on_inviter_id"
    t.index ["project_id", "email"], name: "index_invitations_on_project_id_and_email_pending", unique: true, where: "((accepted_at IS NULL) AND (revoked_at IS NULL))"
    t.index ["token_digest"], name: "index_invitations_on_token_digest", unique: true
    t.check_constraint "role::text = ANY (ARRAY['member'::character varying, 'owner'::character varying]::text[])", name: "invitations_role_check"
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
    t.string "request_open", default: "click", null: false
    t.string "color_scheme", default: "system", null: false
    t.string "theme", default: "default", null: false
    t.boolean "collapse_nested_folders", default: true, null: false
    t.index ["current_environment_id"], name: "index_memberships_on_current_environment_id"
    t.index ["project_id"], name: "index_memberships_on_project_id"
    t.index ["user_id", "project_id"], name: "index_memberships_on_user_id_and_project_id", unique: true, where: "(revoked_at IS NULL)"
    t.check_constraint "color_scheme::text = ANY (ARRAY['system'::character varying, 'light'::character varying, 'dark'::character varying]::text[])", name: "memberships_color_scheme_check"
    t.check_constraint "folder_toggle::text = ANY (ARRAY['click'::character varying, 'double_click'::character varying]::text[])", name: "memberships_folder_toggle_check"
    t.check_constraint "request_open::text = ANY (ARRAY['click'::character varying, 'double_click'::character varying]::text[])", name: "memberships_request_open_check"
    t.check_constraint "role::text = ANY (ARRAY['member'::character varying, 'owner'::character varying]::text[])", name: "memberships_role_check"
    t.check_constraint "theme::text = ANY (ARRAY['default'::character varying, 'blue'::character varying, 'green'::character varying, 'yellow'::character varying, 'red'::character varying, 'purple'::character varying, 'rose'::character varying, 'orange'::character varying, 'mono'::character varying, 'ocean'::character varying, 'forest'::character varying, 'midnight'::character varying, 'nord'::character varying, 'dracula'::character varying, 'gruvbox'::character varying, 'solarized'::character varying, 'sunset'::character varying, 'coffee'::character varying, 'cyberpunk'::character varying, 'graphite'::character varying, 'vulkanite'::character varying, 'virginia_tech'::character varying, 'vague'::character varying, 'van_gogh'::character varying, 'vault'::character varying, 'winslow'::character varying, 'unit_eva_001'::character varying, 'turner'::character varying, 'waveform_dark'::character varying, 'terminus'::character varying, 'synctax'::character varying, 'starsend'::character varying, 'spectrum'::character varying, 'saule'::character varying, 'santa_fe'::character varying, 'robzee84'::character varying, 'rose_pine_moon'::character varying, 'roadster_dark'::character varying, 'red_pill'::character varying, 'periphery'::character varying, 'outpost'::character varying, 'neptune'::character varying, 'alberta'::character varying, 'arc_blueberry'::character varying, 'astral'::character varying, 'azure_glow'::character varying, 'bauhaus'::character varying, 'black_sand'::character varying]::text[])", name: "memberships_theme_check"
  end

  create_table "network_checks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "project_id", null: false
    t.uuid "user_id"
    t.uuid "environment_id"
    t.string "kind", default: "dns", null: false
    t.string "target", null: false
    t.string "outcome", default: "ok", null: false
    t.jsonb "input", default: {}, null: false
    t.jsonb "result", default: {}, null: false
    t.datetime "created_at", null: false
    t.index ["environment_id"], name: "index_network_checks_on_environment_id"
    t.index ["project_id", "kind", "created_at"], name: "index_network_checks_on_project_id_and_kind_and_created_at"
    t.index ["project_id", "kind", "target", "created_at"], name: "index_network_checks_on_project_kind_target_and_created_at"
    t.index ["user_id"], name: "index_network_checks_on_user_id"
    t.check_constraint "kind::text = ANY (ARRAY['dns'::character varying, 'ports'::character varying, 'ping'::character varying]::text[])", name: "network_checks_kind_check"
    t.check_constraint "outcome::text = ANY (ARRAY['ok'::character varying, 'warn'::character varying, 'bad'::character varying]::text[])", name: "network_checks_outcome_check"
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
    t.jsonb "timings", default: {}, null: false
    t.jsonb "set_cookies", default: [], null: false
    t.index ["api_request_id", "created_at"], name: "index_request_executions_on_api_request_id_and_created_at"
    t.index ["api_request_id"], name: "index_request_executions_on_api_request_id"
    t.index ["environment_id"], name: "index_request_executions_on_environment_id"
    t.index ["project_id", "user_id", "created_at"], name: "index_request_executions_on_project_user_and_created_at"
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
  add_foreign_key "audit_events", "projects"
  add_foreign_key "audit_events", "users", column: "actor_id", on_delete: :nullify
  add_foreign_key "audit_events", "users", column: "target_id", on_delete: :nullify
  add_foreign_key "collections", "projects"
  add_foreign_key "collections", "users", column: "creator_id", on_delete: :nullify
  add_foreign_key "cookies", "environments"
  add_foreign_key "cookies", "projects"
  add_foreign_key "environments", "projects"
  add_foreign_key "environments", "users", column: "creator_id", on_delete: :nullify
  add_foreign_key "folders", "collections"
  add_foreign_key "folders", "folders", column: "parent_id"
  add_foreign_key "invitations", "projects"
  add_foreign_key "invitations", "users", column: "inviter_id", on_delete: :nullify
  add_foreign_key "memberships", "environments", column: "current_environment_id", on_delete: :nullify
  add_foreign_key "memberships", "projects"
  add_foreign_key "memberships", "users"
  add_foreign_key "network_checks", "environments", on_delete: :nullify
  add_foreign_key "network_checks", "projects"
  add_foreign_key "network_checks", "users", on_delete: :nullify
  add_foreign_key "request_executions", "api_requests"
  add_foreign_key "request_executions", "environments", on_delete: :nullify
  add_foreign_key "request_executions", "projects"
  add_foreign_key "request_executions", "users", on_delete: :nullify
  add_foreign_key "request_tabs", "api_requests", on_delete: :cascade
  add_foreign_key "request_tabs", "users", on_delete: :cascade
  add_foreign_key "users", "memberships", column: "current_membership_id", on_delete: :nullify
  add_foreign_key "variables", "environments"
end
