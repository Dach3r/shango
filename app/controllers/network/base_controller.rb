module Network
  class BaseController < AuthenticatedController
    include VariableAutocomplete

    helper_method :history_for

    before_action { authorize current_project, :use? }
    throttle :network, by: -> { current_user.id }, if: -> { request.post? }

    private

    def throttled
      render turbo_stream: turbo_stream.update(result_target, partial: "network/shared/throttled"), status: :too_many_requests
    end

    def audit(kind, result, input, **fields)
      details = { user: current_user.id, project: current_project.id, input: input.to_s.truncate(100).inspect, outcome: result.success? ? "ok" : result.error, **fields }
      Rails.logger.info("[network] #{kind} #{details.map { |key, value| "#{key}=#{value}" }.join(" ")}")
    end

    def record_check(kind, input)
      return unless @result.success?

      Network::Checks::Record.call(kind:, result: @result, input:, project: current_project, user: current_user, environment: current_environment).record
    end

    def own_checks
      current_project.network_checks.where(user: current_user)
    end

    def history_for(kind)
      own_checks.where(kind:).recent.limit(NetworkCheck::KEEP_PER_KIND)
    end
  end
end
