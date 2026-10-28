module Network
  # The tools of the Network workspace in rail order. Each one has a page at `/network/<name>`; tools that keep a history
  # store their runs as `NetworkCheck` of their `kind`. A tool can be a preset of another one: it shares its kind, page
  # and history, and `defaults` preselects form values (reverse DNS is the DNS checker with `PTR`).
  module Tools
    Tool = Data.define(:name, :icon, :group, :kind, :defaults) do
      def initialize(name:, icon:, group:, kind: name, defaults: {})
        super
      end
    end

    ALL = [
      Tool.new(name: "dns", icon: "search", group: "dns"),
      Tool.new(name: "reverse_dns", icon: "arrow-left-right", group: "dns", kind: "dns", defaults: { "type" => "PTR" }),
      Tool.new(name: "ports", icon: "radar", group: "connectivity"),
      Tool.new(name: "ping", icon: "activity", group: "connectivity"),
      Tool.new(name: "subnet", icon: "calculator", group: "utilities")
    ].freeze

    module_function

    def names
      ALL.map(&:name)
    end

    def find(name)
      ALL.find { |tool| tool.name == name.to_s } || raise(KeyError, "unknown network tool: #{name}")
    end

    # The tool a saved run belongs to: the most specific one of its kind whose defaults match what was typed.
    def for_run(kind, input)
      ALL.select { |tool| tool.kind == kind.to_s && tool.defaults <= input.to_h }.max_by { |tool| tool.defaults.size }
    end
  end
end
