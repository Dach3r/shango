module Network
  # Shared behavior for the Network Tools feature: every tool runs from the web request, so runs are throttled per user.
  # Successful runs are saved to the project's history (NetworkCheck).
  class BaseController < AuthenticatedController
    include VariableAutocomplete

    helper_method :history_for

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

    # Saves a successful run (`@result`) to the project's history and returns the saved check, or nil.
    def record_check(kind, input)
      return unless @result.success?

      Network::Checks::Record.call(kind:, result: @result, input:, project: current_project, user: current_user, environment: current_environment).record
    end

    def history_for(kind)
      current_project.network_checks.where(kind:).recent.limit(NetworkCheck::KEEP_PER_KIND)
    end
  end
end
