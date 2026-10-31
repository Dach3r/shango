module Projects
  module Searches
    # What the command palette offers for a typed text: the pages and network tools whose name matches, and the project's
    # saved requests and monitors whose name, URL or host contains it. Without text, only the pages. Everything is read
    # through the project.
    class Run
      include Serviceable

      Entry = Data.define(:group, :icon, :title, :detail, :path)

      PAGES = [
        { label: "components.tools_nav.overview", icon: "layout-dashboard", path: :overview_path },
        { label: "components.tools_nav.api_client", icon: "send", path: :workbench_root_path },
        { label: "components.tools_nav.monitoring", icon: "activity", path: :monitoring_root_path },
        { label: "monitoring.tabs.incidents", icon: "siren", path: :monitoring_incidents_path },
        { label: "components.tools_nav.network", icon: "radar", path: :network_root_path }
      ].freeze
      LIMIT = 8
      MAX_LENGTH = 100

      def initialize(project:, query: nil)
        @project = project
        @query = query.to_s.strip.first(MAX_LENGTH)
      end

      private

      def perform
        Result.success(entries: pages + requests + monitors)
      end

      def routes
        Rails.application.routes.url_helpers
      end

      def pages
        entries = PAGES.map { |page| Entry.new(group: :pages, icon: page[:icon], title: I18n.t(page[:label]), detail: nil, path: routes.public_send(page[:path])) }
        entries += Network::Tools::ALL.map { |tool| Entry.new(group: :pages, icon: tool.icon, title: I18n.t("network.tabs.#{tool.name}"), detail: I18n.t("components.tools_nav.network"), path: routes.network_workspace_path(tool.name)) }
        @query.empty? ? entries : entries.select { |entry| entry.title.downcase.include?(@query.downcase) }.first(LIMIT)
      end

      def requests
        return [] if @query.empty?

        @project.api_requests.where("api_requests.name ILIKE :q OR api_requests.url ILIKE :q", q: pattern).includes(:collection).strict_loading.order(:name).limit(LIMIT).map do |request|
          Entry.new(group: :requests, icon: "send", title: request.name.to_s, detail: "#{request.http_method} #{request.collection.name}", path: routes.workbench_request_path(request))
        end
      end

      def monitors
        return [] if @query.empty?

        @project.uptime_monitors.where("name ILIKE :q OR settings->>'url' ILIKE :q OR settings->>'host' ILIKE :q", q: pattern).order(:name).limit(LIMIT).map do |monitor|
          Entry.new(group: :monitors, icon: "activity", title: monitor.name, detail: I18n.t("monitoring.kinds.#{monitor.kind}"), path: routes.monitoring_monitor_path(monitor))
        end
      end

      def pattern
        "%#{ApplicationRecord.sanitize_sql_like(@query)}%"
      end
    end
  end
end
