# Per-actor request limits backed by Rails.cache. Limits are "<count>/<seconds>" pairs that operators can
# override with SHANGO_RATE_LIMIT_<NAME> (e.g. SHANGO_RATE_LIMIT_EXECUTIONS=120/60).
module Throttling
  extend ActiveSupport::Concern

  LIMITS = {
    executions: [60, 1.minute], drafts: [120, 1.minute], oauth: [20, 1.minute], imports: [10, 10.minutes],
    sign_in: [10, 1.minute], sign_up: [10, 1.hour], password_reset: [5, 1.hour], network: [20, 1.minute],
    invitations: [20, 1.hour], invitation_acceptance: [10, 10.minutes]
  }.freeze

  # [count, window] for a named limit, honoring the environment override when it is well formed.
  def self.limit(name)
    default = LIMITS.fetch(name)
    match = ENV["SHANGO_RATE_LIMIT_#{name.to_s.upcase}"].to_s.match(%r{\A(\d+)/(\d+)\z})
    return default unless match

    [match[1].to_i, match[2].to_i.seconds]
  end

  class_methods do
    # Counts each request per actor (the signed-in user, else the IP) and responds with `throttled` once the limit is hit.
    def throttle(name, by: nil, **filters)
      before_action(**filters) { enforce_throttle(name, by) }
    end
  end

  private

  def enforce_throttle(name, by)
    count, window = Throttling.limit(name)
    actor = by ? instance_exec(&by) : request.remote_ip
    used = Rails.cache.increment("throttle/#{name}/#{actor}", 1, expires_in: window)
    return if used.nil? || used <= count

    response.headers["Retry-After"] = window.to_i.to_s
    throttled
  end

  # Default response; controllers with a special client (fetch + Turbo Stream) override it.
  def throttled
    redirect_back_or_to throttled_fallback_path, alert: t("throttling.limited"), status: :see_other
  end

  def throttled_fallback_path
    user_signed_in? ? workbench_root_path : new_user_session_path
  end
end
