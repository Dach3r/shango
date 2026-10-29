module Network
  # The tools of the Network workspace in rail order. Each one has a page at `/network/<name>` and stores its runs as
  # `NetworkCheck` of the same kind.
  module Tools
    Tool = Data.define(:name, :icon, :group)

    ALL = [
      Tool.new(name: "dns", icon: "search", group: "dns"),
      Tool.new(name: "ports", icon: "radar", group: "connectivity"),
      Tool.new(name: "ping", icon: "activity", group: "connectivity"),
      Tool.new(name: "tls", icon: "shield-check", group: "security"),
      Tool.new(name: "subnet", icon: "calculator", group: "utilities")
    ].freeze

    module_function

    def names
      ALL.map(&:name)
    end

    def find(name)
      ALL.find { |tool| tool.name == name.to_s } || raise(KeyError, "unknown network tool: #{name}")
    end
  end
end
