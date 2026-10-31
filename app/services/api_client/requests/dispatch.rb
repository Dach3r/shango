module ApiClient
  module Requests
    # Builds and sends a saved request and returns the (unsaved, secrets masked) RequestExecution, kept as the user's
    # latest response (see LatestExecution) until the user saves it (see Executions::Save). Runs inline or inside RunRequestJob.
    # A collection run (see Runs::Perform) passes `stash: false` (its outcome lives in a run item), `persist: false` when extracted
    # values must not reach the environment, and the `variables` its extractors found so far. Result#data has the values this
    # request extracted (`variables`) and the values among them that are `secrets` (what a masker needs).
    class Dispatch
      include Serviceable

      BODY_LIMIT = Executor::MAX_RESPONSE_BYTES
      TEXT_TYPES = %r{\A(text/|application/(json|xml|javascript|x-www-form-urlencoded|graphql)|.+\+(json|xml))}i

      def initialize(api_request:, environment:, user:, id: SecureRandom.uuid, cancelled: nil, stash: true, persist: true, variables: {}, secrets: [])
        @api_request = api_request
        @environment = environment
        @user = user
        @id = id
        @cancelled = cancelled
        @stash = stash
        @persist = persist
        @variables = variables
        @secrets = secrets
        @extracted = { values: {}, secrets: [] }
      end

      private

      def perform
        built = RequestBuilder.call(api_request: @api_request, environment: @environment, user: @user, variables: @variables, secrets: @secrets)
        execution = built.success? ? execute(built.record) : invalid(built)
        Result.success(@stash ? execution.stash : execution, variables: @extracted[:values], secrets: @extracted[:secrets])
      end

      def execute(built)
        reply = Executor.call(built:, cancelled: @cancelled, cookie_jar: cookie_jar)
        masker = Masker.new(built.secrets)
        body, omitted = displayable_body(reply, masker)
        verified = Verify.call(api_request: @api_request, reply:, environment: @environment, user: @user, masker:, persist: @persist)
        @extracted = { values: verified.data[:values], secrets: verified.data[:secrets].filter_map { |name| verified.data[:values][name] } }
        results = verified.record

        record(
          http_method: built.http_method, url: masker.string(built.url), status: reply.status, status_text: reply.status_text, duration_ms: reply.duration_ms,
          size_bytes: reply.size_bytes, request_headers: masker.request_headers(reply.sent_headers), request_body: masker.string(built.body.preview),
          response_headers: masker.response_headers(reply.headers), response_body: body, content_type: reply.content_type, body_truncated: reply.truncated,
          body_omitted: omitted, redirects: reply.redirects.map { |hop| hop.transform_values { |value| value.is_a?(String) ? masker.string(value) : value } },
          unresolved_variables: built.unresolved, timings: reply.timings, set_cookies: reply.set_cookies.map { |line| masker.string(line) }, error_kind: reply.error_kind, error_message: masker.string(reply.error_message),
          test_results: results
        )
      end

      def cookie_jar
        CookieJar.new(project: @api_request.project, environment: @environment) if @api_request.setting(:use_cookie_jar)
      end

      def invalid(built)
        record(
          http_method: @api_request.http_method, url: @api_request.url.to_s, unresolved_variables: built.data[:unresolved].to_a,
          error_kind: "invalid_request", error_message: built.error
        )
      end

      def record(attributes)
        @api_request.request_executions.build(attributes.merge(id: @id, created_at: Time.current, project: @api_request.project, user: @user, environment: @environment))
      end

      def displayable_body(reply, masker)
        return ["", false] if reply.body.blank?

        text = reply.body.dup.force_encoding(Encoding::UTF_8)
        return [nil, true] unless text.valid_encoding? && !text.include?("\u0000") && (reply.content_type.to_s.match?(TEXT_TYPES) || reply.content_type.blank?)

        [masker.string(text.scrub("")), false]
      end
    end
  end
end
