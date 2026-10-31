module ApiClient
  module Requests
    # Runs a request's assertions and extractors against the reply it just got and stores what the extractors found in the
    # selected environment (see VariableWriteback), unless `persist` is off (a collection run keeps them itself). Result#record is
    # the list of outcomes kept in `RequestExecution#test_results`; Result#data has the extracted `values` and which of them are
    # `secrets`. A transport error has no response to check, so it yields none.
    class Verify
      include Serviceable

      def initialize(api_request:, reply:, environment:, user:, masker:, persist: true)
        @api_request = api_request
        @reply = reply
        @environment = environment
        @user = user
        @masker = masker
        @persist = persist
      end

      private

      def perform
        rules = Automation.call(api_request: @api_request).record
        return Result.success([], values: {}, secrets: []) if @reply.error? || (rules[:assertions].empty? && rules[:extractors].empty?)

        response = Assertions::Evaluator::Response.new(
          status: @reply.status, headers: @reply.headers, body: @reply.body, duration_ms: @reply.duration_ms, size_bytes: @reply.size_bytes
        )
        resolver = VariableResolver.new(@environment&.variable_values || {})
        outcomes = Assertions::Evaluator.call(rows: rules[:assertions], response:, resolver:, masker: @masker)
        extraction = Assertions::Extractor.call(rows: rules[:extractors], response:)
        Result.success(outcomes + extraction.data[:outcomes] + writeback(extraction), values: extraction.record, secrets: extraction.data[:secrets])
      end

      def writeback(extraction)
        return [] if !@persist || extraction.record.empty?

        saved = VariableWriteback.call(environment: @environment, user: @user, values: extraction.record, secrets: extraction.data[:secrets])
        return [] if saved.success?

        [{ "kind" => "extractor", "status" => "warning", "error" => saved.error.to_s }]
      end
    end
  end
end
