class AuthFields::Component < ApplicationComponent
  include ControlsHelper

  VARIABLE_REFERENCE = /\A\{\{.+\}\}\z/

  # scope: form scope owning `auth_type`/`auth_config` (e.g. "api_request").
  # record: the collection, folder or request being edited. `inheritable` adds "Inherit from parent".
  def initialize(scope:, record:, inheritable: false)
    @scope = scope
    @record = record
    @inheritable = inheritable
  end

  private

  def types
    keys = ApiClient::Auth::Registry.keys
    @inheritable ? [AuthConfigurable::INHERIT, *keys] : keys
  end

  def type_options
    types.map { |key| [t("workbench.auth.types.#{key}"), key] }
  end

  def selected_type
    types.include?(@record.auth_type) ? @record.auth_type : types.first
  end

  def strategy(type)
    ApiClient::Auth::Registry.fetch(type)
  end

  def config
    @record.auth_config.to_h
  end

  def field_name(field)
    "#{@scope}[auth_config][#{field.name}]"
  end

  def current_value(field)
    stored = selected_type == @record.auth_type ? config[field.name] : nil
    return stored.presence || field.default unless field.secret

    stored.to_s.match?(VARIABLE_REFERENCE) ? stored : ""
  end

  def secret_saved?(field)
    config[field.name].present? && !config[field.name].to_s.match?(VARIABLE_REFERENCE)
  end

  def option_label(field, option)
    t("workbench.auth.options.#{field.name}.#{option}", default: option.humanize)
  end

  def show_when(field)
    field.show_when.to_h { |name, values| [name.to_s, values] }.to_json
  end

  def draft_request?
    @record.respond_to?(:draft?) && @record.draft?
  end

  def oauth2_token_ready?
    @record.persisted? && @record.auth_type == "oauth2"
  end

  def token_expires_at
    Time.zone.parse(config["expires_at"]) if config["expires_at"].present?
  end

  def dom_id_for(kind)
    "oauth2-#{kind}-#{@record.id}"
  end
end
