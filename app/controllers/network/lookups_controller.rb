module Network
  class LookupsController < BaseController
    def create
      attributes = params.expect(lookup: %i[host])
      @result = Network::Lookups::Run.call(host: attributes[:host], environment: current_environment)
      audit(:lookup, @result, attributes[:host], host: @result.data[:host], type: @result.data[:type])
      @check = record_check(:lookup, attributes)
      return redirect_to(network_check_path(@check), status: :see_other) if @check

      render status: @result.success? ? :ok : :unprocessable_content
    end

    private

    def result_target
      "lookup_result"
    end
  end
end
