module ApiClient
  module Scripting
    # Runs the scripts that apply to a request for one phase (`:pre` before it is built, `:post` after the response), in order and
    # each in a fresh sandbox, carrying what the earlier ones changed (variables, request) into the next. A script that fails stops the
    # rest. Result#record is a State: the tests and console lines they produced, the variables they wrote (see Sandbox::Outcome) and,
    # for `:pre`, the request as they left it.
    class Run
      include Serviceable

      Script = Struct.new(:level, :name, :source, keyword_init: true)
      State = Struct.new(:tests, :logs, :env_writes, :var_writes, :request, :error, keyword_init: true)

      MAX_TESTS = 100
      MAX_LOGS = 200

      def initialize(phase:, scripts:, environment:, request:, variables: {}, response: nil)
        @phase = phase
        @scripts = scripts
        @environment = environment
        @variables = variables
        @request = request
        @response = response
      end

      private

      def perform
        state = State.new(tests: [], logs: [], env_writes: {}, var_writes: {}, request: @request, error: nil)
        @scripts.each do |script|
          outcome = Sandbox.call(source: script.source, phase: @phase, environment: current(@environment, state.env_writes), variables: current(@variables, state.var_writes), request: state.request, response: @response).record
          absorb(state, outcome)
          next unless outcome.error

          state.error = I18n.t("workbench.automation.script_error_in", where: where(script), message: outcome.error)
          break
        end
        Result.success(state)
      end

      def absorb(state, outcome)
        state.tests = (state.tests + outcome.tests).first(MAX_TESTS)
        state.logs = (state.logs + outcome.logs).first(MAX_LOGS)
        state.env_writes = state.env_writes.merge(outcome.env_writes)
        state.var_writes = state.var_writes.merge(outcome.var_writes)
        state.request = outcome.request if @phase == :pre
      end

      # What a script sees: the values it started with, then what earlier scripts wrote (a nil write is an unset).
      def current(base, writes)
        base.merge(writes.compact).except(*writes.select { |_, value| value.nil? }.keys)
      end

      def where(script)
        I18n.t("workbench.automation.script_where", phase: I18n.t("workbench.automation.phases.#{@phase}"), level: I18n.t("workbench.automation.script_levels.#{script.level}", name: script.name))
      end
    end
  end
end
