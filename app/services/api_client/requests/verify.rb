module ApiClient
  module Requests
    # Everything that checks and reacts to the reply a request just got, in this order: post-response scripts, assertions,
    # extractors; then what scripts and extractors wrote to variables is stored in the selected environment (see VariableWriteback),
    # unless `persist` is off (a collection run keeps them itself). `pre` is what the pre-request scripts left (a Scripting::Run::State),
    # `request` the request they left (for the post-response scripts) and `values` the variables the request was built with.
    #
    # Result#record is the list of outcomes kept in `RequestExecution#test_results`; Result#data has `values` (every variable written,
    # to carry into later requests of a run), `secrets` (names among them that are secret), and `logs` (the console lines of all scripts,
    # masked). A transport error has no response to check, so only the writes of the pre-request scripts are kept.
    class Verify
      include Serviceable

      def initialize(api_request:, reply:, environment:, user:, masker:, persist: true, rules: nil, pre: nil, request: nil, values: nil)
        @api_request = api_request
        @reply = reply
        @environment = environment
        @user = user
        @masker = masker
        @persist = persist
        @rules = rules || Automation.call(api_request:).record
        @pre = pre
        @request = request
        @values = values || environment&.variable_values || {}
      end

      private

      def perform
        outcomes = script_outcomes(@pre)
        logs = Array(@pre&.logs)
        env_writes = @pre ? @pre.env_writes : {}
        var_writes = @pre ? @pre.var_writes : {}
        extraction = nil

        unless @reply.error?
          post = Scripting::Run.call(phase: :post, scripts: @rules[:post_scripts], environment: @values, request: @request, variables: var_writes.compact, response: response_data).record if @rules[:post_scripts].any?
          if post
            outcomes += script_outcomes(post)
            logs += post.logs
            env_writes = env_writes.merge(post.env_writes)
            var_writes = var_writes.merge(post.var_writes)
          end
          evaluated = evaluate
          outcomes += evaluated[:outcomes]
          extraction = evaluated[:extraction]
        end

        extracted = extraction ? extraction.record : {}
        written = env_writes.compact.merge(extracted)
        outcomes += writeback(written, extraction&.data&.dig(:secrets).to_a)
        Result.success(outcomes, values: var_writes.compact.merge(written), secrets: secret_names(env_writes, extraction), logs: logs.map { |line| line.merge("text" => @masker.string(line["text"])) })
      end

      def evaluate
        response = Assertions::Evaluator::Response.new(
          status: @reply.status, headers: @reply.headers, body: @reply.body, duration_ms: @reply.duration_ms, size_bytes: @reply.size_bytes
        )
        outcomes = Assertions::Evaluator.call(rows: @rules[:assertions], response:, resolver: VariableResolver.new(@values), masker: @masker)
        extraction = Assertions::Extractor.call(rows: @rules[:extractors], response:)
        { outcomes: outcomes + extraction.data[:outcomes], extraction: }
      end

      def response_data
        { status: @reply.status, status_text: @reply.status_text.to_s, headers: @reply.headers.to_a.map { |name, value| [name.to_s, value.to_s] }, body: @reply.body.to_s.dup.force_encoding(Encoding::UTF_8), duration_ms: @reply.duration_ms }
      end

      def script_outcomes(state)
        return [] unless state

        tests = state.tests.map do |test|
          { "kind" => "script", "status" => test["passed"] ? "passed" : "failed", "name" => @masker.string(test["name"]), "error" => test["message"] && @masker.string(test["message"]) }
        end
        state.error ? tests + [{ "kind" => "script", "status" => "failed", "name" => nil, "error" => @masker.string(state.error) }] : tests
      end

      def writeback(values, secrets)
        return [] if !@persist || values.empty?

        saved = VariableWriteback.call(environment: @environment, user: @user, values:, secrets:)
        saved.success? ? [] : [{ "kind" => "extractor", "status" => "warning", "error" => saved.error.to_s }]
      end

      # Extractor rows that say so, and the variables of the environment that are secret when a script writes them.
      def secret_names(env_writes, extraction)
        secret_keys = @environment ? @environment.variables.select(&:secret).map(&:key) : []
        (extraction&.data&.dig(:secrets).to_a + env_writes.compact.keys.select { |key| secret_keys.include?(key) }).uniq
      end
    end
  end
end
