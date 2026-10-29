module Monitoring
  module Monitors
    class TokensController < BaseController
      before_action :find_monitor

      def create
        authorize @monitor, :update?
        return head(:not_found) unless @monitor.push?

        token = Monitoring::Monitors::RegenerateToken.call(monitor: @monitor, actor: current_user).data[:push_token]
        session[MonitorsController::PUSH_TOKEN] = { "id" => @monitor.id, "token" => token }
        redirect_to monitoring_monitor_path(@monitor), notice: t(".regenerated"), status: :see_other
      end
    end
  end
end
