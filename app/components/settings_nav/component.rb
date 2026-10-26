class SettingsNav::Component < ApplicationComponent
  # Settings sections grouped by scope; only entries with a path are live.
  GROUPS = [
    { key: :account, items: [{ key: :profile, icon: "user" }, { key: :security, icon: "shield" }] },
    { key: :membership, items: [{ key: :sidebar, icon: "panel-left", path: :edit_membership_path, controllers: "projects/memberships" }] },
    { key: :project, items: [{ key: :members, icon: "users" }] }
  ].freeze

  def initialize(project:)
    @project = project
  end

  private

  def groups
    GROUPS.map do |group|
      { label: t("components.settings_nav.groups.#{group[:key]}", project: @project.name), items: items(group[:items]) }
    end
  end

  def items(entries)
    entries.map do |item|
      href = item[:path] && helpers.public_send(item[:path])
      { label: t("components.settings_nav.items.#{item[:key]}"), icon: item[:icon], href:, active: href.present? && helpers.controller_path == item[:controllers] }
    end
  end
end
