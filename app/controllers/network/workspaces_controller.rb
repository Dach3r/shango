module Network
  class WorkspacesController < BaseController
    def show
      @tool = Network::Tools.find(params[:kind].presence || "dns")
      @prefill = { "host" => params[:target], "port" => params[:port_number] }.transform_values { |value| value.to_s.first(NetworkCheck::INPUT_LIMIT) }.compact_blank
    end
  end
end
