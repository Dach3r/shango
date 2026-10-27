module ApiClient
  module Executions
    # Bookkeeping for a run that executes in the background: the browser polls it, and can ask to cancel it. Lives in
    # the shared cache for a few minutes; the response itself is the pending RequestExecution stashed by Requests::Dispatch.
    module RunState
      TTL = 5.minutes

      class << self
        def start(id, user_id:, api_request_id:, uploaded: false)
          write(id, "state" => "running", "user_id" => user_id, "api_request_id" => api_request_id, "uploaded" => uploaded)
        end

        def read(id)
          Rails.cache.read(key(id))
        end

        # The state when it belongs to this user and request, else nil.
        def for(id, user_id:, api_request_id:)
          state = read(id)
          state if state && state["user_id"] == user_id && state["api_request_id"] == api_request_id
        end

        def finish(id, state)
          current = read(id)
          write(id, current.merge("state" => state)) if current
        end

        def cancel(id)
          Rails.cache.write(cancel_key(id), true, expires_in: TTL)
        end

        def cancelled?(id)
          Rails.cache.read(cancel_key(id)) == true
        end

        private

        def write(id, state)
          Rails.cache.write(key(id), state, expires_in: TTL)
        end

        def key(id)
          "request_execution/run/#{id}"
        end

        def cancel_key(id)
          "request_execution/cancel/#{id}"
        end
      end
    end
  end
end
