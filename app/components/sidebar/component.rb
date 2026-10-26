class Sidebar::Component < ApplicationComponent
  # Project tools from the product navigation; only entries with a path are live.
  ITEMS = [
    { key: :overview, icon: "layout-dashboard", path: :root_path },
    { key: :api_client, icon: "send" },
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
      { label: t("components.sidebar.#{item[:key]}"), icon: item[:icon], href:, active: href.present? && helpers.current_page?(href) }
    end
  end
end
