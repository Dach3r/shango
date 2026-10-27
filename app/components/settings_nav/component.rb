class SettingsNav::Component < ApplicationComponent
  # Settings sections grouped by scope; only entries with a path are live.
  GROUPS = [
    { key: :account, items: [
      { key: :profile, icon: "user", path: :edit_user_registration_path, controllers: "users/registrations", tab: "profile" },
      { key: :security, icon: "shield", path: :edit_user_registration_path, params: { tab: "security" }, controllers: "users/registrations", tab: "security" },
      { key: :delete_account, icon: "trash-2", path: :edit_user_registration_path, params: { tab: "delete_account" }, controllers: "users/registrations", tab: "delete_account" }
    ] },
    { key: :appearance, items: [
      { key: :preferences, icon: "sliders-horizontal", path: :edit_user_registration_path, params: { tab: "preferences" }, controllers: "users/registrations", tab: "preferences" },
      { key: :themes, icon: "palette", path: :edit_theme_path, controllers: "projects/themes" },
      { key: :sidebar, icon: "panel-left", path: :edit_membership_path, controllers: "projects/memberships" }
    ] },
    { key: :project, items: [{ key: :members, icon: "users" }] }
  ].freeze

  def initialize(project:)
    @project = project
  end

  private

  def groups
    GROUPS.map do |group|
      { label: t("components.settings_nav.groups.#{group[:key]}"), items: items(group[:items]) }
    end
  end

  def items(entries)
    entries.map do |item|
      href = item[:path] && helpers.public_send(item[:path], **item.fetch(:params, {}))
      { label: t("components.settings_nav.items.#{item[:key]}"), icon: item[:icon], href:, active: href.present? && active?(item) }
    end
  end

  def active?(item)
    helpers.controller_path == item[:controllers] && (item[:tab].nil? || item[:tab] == current_tab)
  end

  def current_tab
    helpers.params[:tab].presence_in(Users::RegistrationsController::TABS) || Users::RegistrationsController::TABS.first
  end
end
