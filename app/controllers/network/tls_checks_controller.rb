module Network
  class TlsChecksController < BaseController
    def create
      attributes = params.expect(tls_check: %i[host port protocol])
      @result = Network::TlsChecks::Run.call(host: attributes[:host], port: attributes[:port], protocol: attributes[:protocol], environment: current_environment)
      audit(:tls_check, @result, attributes[:host], host: @result.data[:host], port: @result.data[:port], protocol: @result.data[:protocol])
      @check = record_check(:tls, attributes)
      return redirect_to(network_check_path(@check), status: :see_other) if @check

      render status: @result.success? ? :ok : :unprocessable_content
    end

    private

    def result_target
      "tls_result"
    end
  end
end
