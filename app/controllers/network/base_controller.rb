module Network
  # Shared behavior for the Network Tools feature: every tool runs from the web request, so runs are throttled per user.
  class BaseController < AuthenticatedController
    throttle :network, by: -> { current_user.id }, if: -> { request.post? }

    private

    # Controllers define `result_target`: the Turbo Stream target that shows the tool's result.
    def throttled
      render turbo_stream: turbo_stream.update(result_target, partial: "network/shared/throttled"), status: :too_many_requests
    end

    # One log line per connection made on behalf of a user, so scans from this server can be traced back.
    def audit(kind, result, input, **fields)
      details = { user: current_user.id, project: current_project.id, input: input.to_s.truncate(100).inspect, outcome: result.success? ? "ok" : result.error, **fields }
      Rails.logger.info("[network] #{kind} #{details.map { |key, value| "#{key}=#{value}" }.join(" ")}")
    end
  end
end
