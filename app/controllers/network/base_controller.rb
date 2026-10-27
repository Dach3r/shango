module Network
  # Shared behavior for the Network Tools feature: every tool runs from the web request, so runs are throttled per user.
  class BaseController < AuthenticatedController
    throttle :network, by: -> { current_user.id }, if: -> { request.post? }

    private

    # Controllers define `result_target`: the Turbo Stream target that shows the tool's result.
    def throttled
      render turbo_stream: turbo_stream.update(result_target, partial: "network/shared/throttled"), status: :too_many_requests
    end
  end
end
