module Shango
  # Push monitor URLs carry their secret token in the path, and `filter_parameters` does not cover paths, so requests
  # to them are served without writing to the Rails log ("Started GET /monitoring/push/<token>" included).
  class SilencePushLogs
    PREFIX = "/monitoring/push".freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env) unless env["PATH_INFO"].to_s.start_with?(PREFIX)

      Rails.logger.silence(Logger::ERROR) { @app.call(env) }
    end
  end
end
