class Sidebar::Component < ApplicationComponent
  # Project tools from the product navigation; only entries with a path are live.
  ITEMS = [
    { key: :overview, icon: "layout-dashboard", path: :root_path },
    { key: :api_client, icon: "send", path: :workbench_root_path, controllers: "workbench/" },
    { key: :environments, icon: "layers", path: :environments_path, controllers: "projects/environments" },
    { key: :documentation, icon: "book-open" },
    { key: :monitoring, icon: "activity" },
    { key: :servers, icon: "server" },
    { key: :logs, icon: "scroll-text" },
    { key: :ai_assistant, icon: "sparkles" },
    { key: :settings, icon: "settings" }
  ].freeze

  def initialize(current_project:, projects:)
    @current_project = current_project
    @projects = projects
  end

  private

  def items
    ITEMS.map do |item|
      href = item[:path] && helpers.public_send(item[:path])
      { label: t("components.sidebar.#{item[:key]}"), icon: item[:icon], href:, active: active?(item, href) }
    end
  end

  # Features with their own controllers stay highlighted on every screen of the feature.
  def active?(item, href)
    return false if href.blank?
    return helpers.controller_path.start_with?(item[:controllers]) if item[:controllers]

    helpers.current_page?(href)
  end
end
