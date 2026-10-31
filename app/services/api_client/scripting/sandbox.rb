module ApiClient
  module Scripting
    # Runs one script in a fresh QuickJS context with no way out: the context has no host functions, no I/O and no timers (see pm.js).
    # What the script may see goes in as one JSON document and what it changed comes back as another, so the only thing that crosses
    # the boundary is data. A script that loops forever or eats memory is stopped by the engine (SHANGO_SCRIPT_TIMEOUT_MS,
    # SHANGO_SCRIPT_MEMORY_MB) and reported as an ordinary script error.
    class Sandbox
      include Serviceable

      BOOTSTRAP = File.read(File.join(__dir__, "pm.js")).freeze
      DEFAULT_TIMEOUT_MS = 2_000
      MAX_TIMEOUT_MS = 10_000
      DEFAULT_MEMORY_MB = 32
      MAX_MEMORY_MB = 128
      MAX_SOURCE = 64.kilobytes
      MAX_RESULT = 2.megabytes
      MAX_BODY = 1.megabyte
      MAX_WRITES = 50
      MAX_VALUE = 64.kilobytes

      # `env_writes` and `var_writes` map a variable name to its new value, or to nil when the script unset it.
      Outcome = Struct.new(:tests, :logs, :env_writes, :var_writes, :request, :error, keyword_init: true)

      def self.timeout_ms
        ENV.fetch("SHANGO_SCRIPT_TIMEOUT_MS", DEFAULT_TIMEOUT_MS).to_i.clamp(100, MAX_TIMEOUT_MS)
      end

      def self.memory_bytes
        ENV.fetch("SHANGO_SCRIPT_MEMORY_MB", DEFAULT_MEMORY_MB).to_i.clamp(4, MAX_MEMORY_MB).megabytes
      end

      # `request` is `{ url:, http_method:, headers: [{ key:, value:, enabled: }], body: }`; `response` (post-response only) is
      # `{ status:, status_text:, headers: [[name, value]], body:, duration_ms: }`.
      def initialize(source:, phase:, environment:, variables:, request:, response: nil)
        @source = source.to_s
        @phase = phase.to_s
        @environment = environment
        @variables = variables
        @request = request
        @response = response
      end

      private

      def perform
        return failed("too_large") if @source.bytesize > MAX_SOURCE

        Result.success(parse(execute))
      rescue Quickjs::InterruptedError
        failed("timeout")
      rescue StandardError => error
        failed(error.message.to_s.lines.first.to_s.strip.first(MAX_RESULT_LINE).presence || error.class.name)
      end

      MAX_RESULT_LINE = 300

      def execute
        vm = Quickjs::VM.new(timeout_msec: self.class.timeout_ms, memory_limit: self.class.memory_bytes)
        begin
          vm.eval_code(BOOTSTRAP)
          vm.call("__shango_run", @phase, JSON.generate(payload), @source)
        ensure
          vm.dispose!
        end
      end

      def payload
        data = { environment: @environment, variables: @variables, request: @request }
        data[:response] = @response.merge(body: @response[:body].to_s.byteslice(0, MAX_BODY)) if @response
        clean(data)
      end

      # Bodies and header values arrive as raw bytes; JSON needs valid UTF-8.
      def clean(object)
        case object
        when String then object.dup.force_encoding(Encoding::UTF_8).scrub("")
        when Array then object.map { |item| clean(item) }
        when Hash then object.to_h { |key, value| [clean(key), clean(value)] }
        else object
        end
      end

      def parse(json)
        raise "result_too_large" if json.bytesize > MAX_RESULT

        data = JSON.parse(json)
        Outcome.new(
          tests: data["tests"].first(100).map { |test| { "name" => test["name"].to_s, "passed" => test["passed"] == true, "message" => test["message"]&.to_s } },
          logs: data["logs"].first(200).map { |line| { "level" => line["level"].to_s, "text" => line["text"].to_s } },
          env_writes: writes(data["env_writes"]), var_writes: writes(data["var_writes"]), request: request(data["request"]), error: data["error"]&.to_s&.first(MAX_RESULT_LINE)
        )
      end

      def writes(map)
        map.to_h.filter_map do |key, value|
          [key.to_s, value&.to_s&.byteslice(0, MAX_VALUE)&.scrub("")] if key.to_s.match?(Variable::KEY_FORMAT)
        end.first(MAX_WRITES).to_h
      end

      def request(data)
        {
          url: data["url"].to_s, http_method: data["http_method"].to_s.upcase,
          headers: Array(data["headers"]).first(100).map { |row| { "key" => row["key"].to_s, "value" => row["value"].to_s, "enabled" => row["enabled"] != false, "description" => row["description"].to_s } },
          body: data["body"].to_s
        }
      end

      def failed(message)
        Result.success(Outcome.new(tests: [], logs: [], env_writes: {}, var_writes: {}, request: @request, error: message))
      end
    end
  end
end
