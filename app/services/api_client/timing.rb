module ApiClient
  # Accumulates per-phase durations (in seconds) across every attempt of one execution (redirects and digest retries
  # included). Connection.build times DNS, #probe hooks a Net::HTTP connection to time connect/TLS, and the executor
  # brackets each attempt with #begin_attempt / #end_attempt to split waiting (TTFB) from download.
  class Timing
    def initialize
      @seconds = Hash.new(0.0)
    end

    def measure(phase)
      started = now
      yield
    ensure
      @seconds[phase] += now - started
    end

    def probe(http)
      timing = self
      http.define_singleton_method(:connect) do
        timing.measure(:connect) { super() }
        timing.connected!
      end
      http.define_singleton_method(:ssl_socket_connect) { |socket, timeout| timing.measure(:tls) { super(socket, timeout) } }
    end

    def begin_attempt
      @attempt_started = now
      @connected_at = nil
      @first_byte_at = nil
    end

    def connected!
      @connected_at = now
    end

    def first_byte!
      @first_byte_at ||= now
    end

    def end_attempt
      finished = now
      first_byte = @first_byte_at || finished
      @seconds[:ttfb] += first_byte - (@connected_at || @attempt_started)
      @seconds[:download] += finished - first_byte
    end

    # Milliseconds per phase; "process" is whatever part of the total the network phases do not explain.
    def to_h(total_ms)
      phases = {
        "dns" => @seconds[:dns], "tcp" => [@seconds[:connect] - @seconds[:tls], 0].max, "tls" => @seconds[:tls],
        "ttfb" => @seconds[:ttfb], "download" => @seconds[:download]
      }
      phases["process"] = [total_ms / 1000.0 - phases.values.sum, 0].max
      phases.transform_values { |seconds| (seconds * 1000).round(2) }
    end

    private

    def now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
