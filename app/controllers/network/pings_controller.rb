module Network
  class PingsController < BaseController
    def create
      attributes = params.expect(ping: %i[host port attempts])
      @result = Network::Pings::Run.call(host: attributes[:host], port: attributes[:port], attempts: attributes[:attempts], environment: current_environment)
      audit(:ping, @result, attributes[:host], host: @result.data[:host], port: @result.data[:port])
      @check = record_check(:ping, attributes)
      return redirect_to(network_check_path(@check), status: :see_other) if @check

      render status: @result.success? ? :ok : :unprocessable_content
    end

    private

    def result_target
      "ping_result"
    end
  end
end
