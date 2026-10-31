module ApiClient
  module Runs
    # Sends the requests of a run one after another (a chain depends on its order), each through the regular Requests::Dispatch
    # with the variables the earlier ones extracted, and records the outcome of every one in its item. A request fails when it could
    # not be sent or any of its assertions failed. Cancelling (see Cancel) is looked up before every request and aborts the one in flight.
    class Perform
      include Serviceable

      def initialize(run:, pause: ->(seconds) { sleep(seconds) })
        @run = run
        @pause = pause
        @variables = {}
        @secrets = []
      end

      private

      def perform
        return Result.failure(@run) unless @run.may_start?

        @run.start!
        return stop(:access_revoked) unless access?

        @run.items.each_with_index do |item, index|
          break if cancelled?

          pause if index.positive?
          step(item)
          break if stop_after_failure?
        end
        close
      rescue StandardError => error
        Rails.logger.error("Collection run #{@run.id} failed: #{error.class}: #{error.message}")
        stop(:unexpected)
      end

      def access?
        Membership.active.exists?(project_id: @run.project_id, user_id: @run.user_id)
      end

      def step(item)
        item.start!
        api_request = item.api_request
        return skip(item, "request_deleted") unless api_request && api_request.project_id == @run.project_id

        sent = Requests::Dispatch.call(
          api_request:, environment: @run.environment, user: @run.user, stash: false, persist: @run.option(:persist_variables),
          variables: @variables, secrets: @secrets, cancelled: -> { cancelled? }
        )
        @variables.merge!(sent.data[:variables])
        @secrets.concat(sent.data[:secrets])
        record(item, sent.record)
      end

      def record(item, execution)
        item.reload
        return unless item.running?

        item.assign_attributes(
          http_status: execution.status, duration_ms: execution.duration_ms, url: execution.url, test_results: execution.test_results,
          error_kind: execution.error_kind, error_message: execution.error_message
        )
        return skip(item, "cancelled") if execution.error_kind == "cancelled"

        failed = execution.error? || execution.failed_tests.positive?
        failed ? item.mark_failed! : item.mark_passed!
        count(failed)
      end

      def skip(item, reason)
        item.update!(error_kind: reason)
        item.mark_skipped!
      end

      def count(failed)
        @run.update!(failed ? { failed_count: @run.failed_count + 1 } : { passed_count: @run.passed_count + 1 })
        broadcast
      end

      def stop_after_failure?
        @run.option(:stop_on_failure) && @run.failed_count.positive?
      end

      def pause
        delay = @run.option(:delay_ms)
        @pause.call(delay / 1000.0) if delay.positive?
      end

      def cancelled?
        CollectionRun.where(id: @run.id).pick(:status) == "cancelled"
      end

      def close
        skip_rest
        @run.reload
        @run.finish! if @run.running?
        broadcast
        Result.success(@run)
      end

      def skip_rest
        @run.items.reload.each { |item| item.mark_skipped! if item.pending? }
      end

      def stop(reason)
        @run.reload
        @run.break_down!(reason.to_s) if @run.may_break_down?
        @run.update!(error: reason.to_s)
        broadcast
        Result.failure(@run, error: reason)
      end

      def broadcast
        Turbo::StreamsChannel.broadcast_refresh_to(@run)
      end
    end
  end
end
