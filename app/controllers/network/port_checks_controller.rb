module Network
  class PortChecksController < BaseController
    def create
      attributes = params.expect(port_check: %i[host ports])
      @result = Network::PortChecks::Run.call(host: attributes[:host], ports: attributes[:ports], environment: current_environment)
      audit(:port_check, @result, attributes[:host], host: @result.data[:host], ports: @result.data[:rows]&.size)
      render status: @result.success? ? :ok : :unprocessable_content
    end

    private

    def result_target
      "ports_result"
    end
  end
end
