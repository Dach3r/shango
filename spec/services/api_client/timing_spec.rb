require "rails_helper"

RSpec.describe ApiClient::Timing do
  subject(:timing) { described_class.new }

  def advance(seconds)
    @now = (@now || 100.0) + seconds
  end

  before do
    @now = 100.0
    allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC) { @now }
  end

  describe "#measure" do
    it "accumulates the time spent in a phase, even when the block raises", :aggregate_failures do
      timing.measure(:dns) { advance(0.03) }
      expect { timing.measure(:dns) { advance(0.01) && raise("boom") } }.to raise_error("boom")

      expect(timing.to_h(40)["dns"]).to eq(40.0)
    end
  end

  describe "#probe" do
    let(:socket_class) do
      Class.new do
        attr_reader :log

        def initialize(clock)
          @clock = clock
          @log = []
        end

        def connect
          @clock.call(0.05)
          ssl_socket_connect(:socket, 5)
        end

        private

        def ssl_socket_connect(socket, timeout)
          @clock.call(0.03)
          @log << [socket, timeout]
        end
      end
    end

    it "splits connect time into TCP and TLS", :aggregate_failures do
      http = socket_class.new(method(:advance))
      timing.probe(http)
      timing.begin_attempt
      http.connect
      timing.first_byte!
      timing.end_attempt

      expect(http.log).to eq([[:socket, 5]])
      expect(timing.to_h(80)).to include("tcp" => 50.0, "tls" => 30.0)
    end
  end

  describe "#to_h" do
    it "splits waiting from download and keeps the remainder as processing", :aggregate_failures do
      timing.begin_attempt
      timing.connected!
      advance(0.2)
      timing.first_byte!
      advance(0.1)
      timing.first_byte!
      advance(0.1)
      timing.end_attempt

      expect(timing.to_h(500)).to eq("dns" => 0.0, "tcp" => 0.0, "tls" => 0.0, "ttfb" => 200.0, "download" => 200.0, "process" => 100.0)
    end

    it "counts everything as waiting when no data arrives" do
      timing.begin_attempt
      advance(0.3)
      timing.end_attempt

      expect(timing.to_h(300)).to include("ttfb" => 300.0, "download" => 0.0, "process" => 0.0)
    end

    it "never reports a negative processing time" do
      timing.measure(:dns) { advance(0.5) }

      expect(timing.to_h(100)["process"]).to eq(0.0)
    end
  end
end
