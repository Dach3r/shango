RSpec.describe TimingHelper do
  describe "#timing_rows" do
    def execution(timings)
      build(:request_execution, timings:)
    end

    it "lays the phases out as a waterfall", :aggregate_failures do
      rows = helper.timing_rows(execution("dns" => 10.0, "tcp" => 10.0, "tls" => 0.0, "ttfb" => 60.0, "download" => 20.0, "process" => 0.0))

      expect(rows.map { |row| row[:phase] }).to eq(%w[dns tcp ttfb download process])
      expect(rows.map { |row| row[:left] }).to eq([0.0, 10.0, 20.0, 80.0, 99.0])
      expect(rows.map { |row| row[:width] }).to eq([10.0, 10.0, 60.0, 20.0, 1.0])
    end

    it "keeps a TLS row when it took time" do
      expect(helper.timing_rows(execution("tls" => 5.0, "ttfb" => 5.0)).map { |row| row[:phase] }).to eq(%w[tls ttfb])
    end

    it "is empty without timings", :aggregate_failures do
      expect(helper.timing_rows(execution({}))).to eq([])
      expect(helper.timing_rows(execution("dns" => 0.0))).to eq([])
    end
  end
end
