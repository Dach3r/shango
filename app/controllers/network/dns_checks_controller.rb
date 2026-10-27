module Network
  class DnsChecksController < BaseController
    def create
      attributes = params.expect(dns_check: %i[domain type expected])
      @result = Network::DnsChecks::Run.call(domain: attributes[:domain], type: attributes[:type], expected: attributes[:expected], environment: current_environment)
      render status: @result.success? ? :ok : :unprocessable_entity
    end

    private

    def result_target
      "dns_result"
    end
  end
end
