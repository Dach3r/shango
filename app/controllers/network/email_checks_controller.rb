module Network
  class EmailChecksController < BaseController
    def create
      attributes = params.expect(email_check: %i[domain])
      domain, selectors = attributes[:domain].to_s.strip.split(/\s+/, 2)
      @result = Network::EmailChecks::Run.call(domain: domain.to_s, selectors:, environment: current_environment)
      audit(:email_check, @result, attributes[:domain], host: @result.data[:host])
      @check = record_check(:email, { domain:, selectors: }.compact)
      return redirect_to(network_check_path(@check), status: :see_other) if @check

      render status: @result.success? ? :ok : :unprocessable_content
    end

    private

    def result_target
      "email_result"
    end
  end
end
