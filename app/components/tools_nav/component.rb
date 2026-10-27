class ToolsNav::Component < ApplicationComponent
  # Project tools from the product navigation; only entries with a path are live.
  ITEMS = [
    { key: :api_client, icon: "send", path: :workbench_root_path },
    { key: :documentation, icon: "book-open" },
    { key: :monitoring, icon: "activity" },
    { key: :servers, icon: "server" },
    { key: :network, icon: "radar", path: :network_root_path },
    { key: :logs, icon: "scroll-text" },
    { key: :ai_assistant, icon: "sparkles" }
  ].freeze

  private

  def items
    @items ||= ITEMS.map do |item|
      { label: t("components.tools_nav.#{item[:key]}"), icon: item[:icon], href: item[:path] && helpers.public_send(item[:path]) }
    end
  end
end
