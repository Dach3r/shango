module Monitoring
  # The URL a job, cron or backup calls on each run of a push monitor: `/monitoring/push/<token>`, or
  # `/monitoring/push` with the token in `X-Shango-Push-Token`. No session and no CSRF token (the caller is a script);
  # the secret token is the credential. Answers 204, 404 for an unknown token, 429 when called too often. The path is
  # kept out of the request log by Shango::SilencePushLogs.
  class PushesController < ActionController::Base
    include Throttling

    HEADER = "X-Shango-Push-Token".freeze

    skip_forgery_protection
    throttle :push_ip
    throttle :push, by: -> { UptimeMonitor.digest(token) }

    def create
      result = Monitoring::Monitors::Ping.call(token:)
      head(result.success? ? :no_content : :not_found)
    end

    private

    def token
      params[:token].presence || request.headers[HEADER].to_s
    end

    def throttled
      head :too_many_requests
    end
  end
end
