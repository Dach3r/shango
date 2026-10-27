module Network
  class DnsChecksController < BaseController
    def create
      attributes = params.expect(dns_check: %i[domain type])
      domain, expected = attributes[:domain].to_s.strip.split(/\s+/, 2)
      @result = Network::DnsChecks::Run.call(domain: domain.to_s, type: attributes[:type], expected:, environment: current_environment)
      @check = record_check(:dns, { domain:, type: attributes[:type], expected: }.compact)
      return redirect_to(network_check_path(@check), status: :see_other) if @check

      render status: @result.success? ? :ok : :unprocessable_content
    end

    private

    def result_target
      "dns_result"
    end
  end
end
