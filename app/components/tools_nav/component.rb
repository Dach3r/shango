class ToolsNav::Component < ApplicationComponent
  # Project tools from the product navigation; only entries with a path are live.
  ITEMS = [
    { key: :overview, icon: "layout-dashboard", path: :overview_path },
    { key: :api_client, icon: "send", path: :workbench_root_path },
    { key: :documentation, icon: "book-open" },
    { key: :monitoring, icon: "activity", path: :monitoring_root_path, badge: :open_incidents },
    { key: :servers, icon: "server" },
    { key: :network, icon: "radar", path: :network_root_path },
    { key: :logs, icon: "scroll-text" },
    { key: :ai_assistant, icon: "sparkles" }
  ].freeze

  # `open_incidents` is the count flagged on Monitoring.
  def initialize(open_incidents: 0)
    @counts = { open_incidents: }
  end

  private

  def items
    @items ||= ITEMS.map do |item|
      { label: t("components.tools_nav.#{item[:key]}"), icon: item[:icon], href: item[:path] && helpers.public_send(item[:path]), badge: @counts[item[:badge]] }
    end
  end
end
