class Sidebar::Component < ApplicationComponent
  # Project tools from the product navigation; only entries with a path are live.
  ITEMS = [
    { key: :api_client, icon: "send", path: :workbench_root_path, controllers: "workbench/" },
    { key: :environments, icon: "layers", path: :environments_path, controllers: "projects/environments" },
    { key: :documentation, icon: "book-open" },
    { key: :monitoring, icon: "activity" },
    { key: :servers, icon: "server" },
    { key: :logs, icon: "scroll-text" },
    { key: :ai_assistant, icon: "sparkles" }
  ].freeze

  SETTINGS = { key: :settings, icon: "settings", path: :edit_membership_path, controllers: "projects/memberships" }.freeze

  def initialize(current_project:, projects:, user:)
    @current_project = current_project
    @projects = projects
    @user = user
  end

  private

  def live_items
    items.select { |item| item[:href] }
  end

  def soon_items
    items.reject { |item| item[:href] }
  end

  def items
    @items ||= ITEMS.map { |item| nav_item(item) }
  end

  def settings
    nav_item(SETTINGS)
  end

  def nav_item(item)
    href = item[:path] && helpers.public_send(item[:path])
    { label: t("components.sidebar.#{item[:key]}"), icon: item[:icon], href:, active: active?(item, href) }
  end

  # Features with their own controllers stay highlighted on every screen of the feature.
  def active?(item, href)
    href.present? && helpers.controller_path.start_with?(item[:controllers])
  end
end
