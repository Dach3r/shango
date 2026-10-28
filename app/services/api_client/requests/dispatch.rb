module ApiClient
  module Requests
    # Builds and sends a saved request and returns the (unsaved, secrets masked) RequestExecution, kept as the user's
    # latest response (see LatestExecution) until the user saves it (see Executions::Save). Runs inline or inside RunRequestJob.
    class Dispatch
      include Serviceable

      BODY_LIMIT = Executor::MAX_RESPONSE_BYTES
      TEXT_TYPES = %r{\A(text/|application/(json|xml|javascript|x-www-form-urlencoded|graphql)|.+\+(json|xml))}i

      def initialize(api_request:, environment:, user:, id: SecureRandom.uuid, cancelled: nil)
        @api_request = api_request
        @environment = environment
        @user = user
        @id = id
        @cancelled = cancelled
      end

      private

      def perform
        built = RequestBuilder.call(api_request: @api_request, environment: @environment, user: @user)
        execution = built.success? ? execute(built.record) : invalid(built)
        Result.success(execution.stash)
      end

      def execute(built)
        reply = Executor.call(built:, cancelled: @cancelled, cookie_jar: cookie_jar)
        masker = Masker.new(built.secrets)
        body, omitted = displayable_body(reply, masker)

        record(
          http_method: built.http_method, url: masker.string(built.url), status: reply.status, status_text: reply.status_text, duration_ms: reply.duration_ms,
          size_bytes: reply.size_bytes, request_headers: masker.request_headers(reply.sent_headers), request_body: masker.string(built.body.preview),
          response_headers: masker.response_headers(reply.headers), response_body: body, content_type: reply.content_type, body_truncated: reply.truncated,
          body_omitted: omitted, redirects: reply.redirects.map { |hop| hop.transform_values { |value| value.is_a?(String) ? masker.string(value) : value } },
          unresolved_variables: built.unresolved, timings: reply.timings, set_cookies: reply.set_cookies.map { |line| masker.string(line) }, error_kind: reply.error_kind, error_message: masker.string(reply.error_message)
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
