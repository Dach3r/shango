require "rails_helper"

RSpec.describe ApiClientHelper do
  describe "#format_duration" do
    it "formats nil, milliseconds and seconds", :aggregate_failures do
      expect(helper.format_duration(nil)).to eq("-")
      expect(helper.format_duration(250)).to eq("250 ms")
      expect(helper.format_duration(1500)).to eq("1.50 s")
    end
  end

  describe "#format_timing" do
    it "adapts the precision to the magnitude", :aggregate_failures do
      expect(helper.format_timing(0.3)).to eq("0.30 ms")
      expect(helper.format_timing(143.4)).to eq("143 ms")
      expect(helper.format_timing(1250.0)).to eq("1.25 s")
    end
  end

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

  describe "#format_size" do
    it "humanizes bytes" do
      expect(helper.format_size(2048)).to eq("2 KB")
    end
  end

  describe "#body_language" do
    it "maps content types", :aggregate_failures do
      expect(helper.body_language("application/json")).to eq("json")
      expect(helper.body_language("text/xml")).to eq("xml")
      expect(helper.body_language("text/html")).to eq("html")
      expect(helper.body_language("application/javascript")).to eq("javascript")
      expect(helper.body_language("text/plain")).to eq("text")
      expect(helper.body_language(nil)).to eq("text")
    end
  end

  describe "#pretty_body" do
    def execution(body, type)
      build(:request_execution, response_body: body, content_type: type)
    end

    it "pretty prints JSON" do
      expect(helper.pretty_body(execution('{"a":1}', "application/json"))).to eq("{\n  \"a\": 1\n}")
    end

    it "returns raw text for invalid JSON" do
      expect(helper.pretty_body(execution("not json", "application/json"))).to eq("not json")
    end

    it "pretty prints XML" do
      expect(helper.pretty_body(execution("<a><b>1</b></a>", "application/xml"))).to eq("<?xml version=\"1.0\"?>\n<a>\n  <b>1</b>\n</a>\n")
    end

    it "returns raw text for invalid XML" do
      expect(helper.pretty_body(execution("<a><b>", "application/xml"))).to eq("<a><b>")
    end

    it "returns other bodies as is", :aggregate_failures do
      expect(helper.pretty_body(execution("hi", "text/plain"))).to eq("hi")
      expect(helper.pretty_body(execution(nil, nil))).to eq("")
    end
  end

  describe "#param_rows" do
    it "returns saved rows" do
      request = build(:api_request, query_params: [{ "key" => "a", "value" => "1" }])
      request.valid?

      expect(helper.param_rows(request)).to eq(request.query_params)
    end

    it "parses the URL query string when none saved", :aggregate_failures do
      request = build(:api_request, url: "https://x.test/p?a=1&b=hello%20w&flag&&#frag")

      expect(helper.param_rows(request)).to contain_exactly(
        { "key" => "a", "value" => "1", "enabled" => true, "description" => "" },
        { "key" => "b", "value" => "hello w", "enabled" => true, "description" => "" },
        { "key" => "flag", "value" => "", "enabled" => true, "description" => "" }
      )
    end

    it "returns nothing without a query string" do
      expect(helper.param_rows(build(:api_request, url: "https://x.test/p"))).to be_empty
    end
  end

  describe "#body_type_options" do
    it "pairs translated labels with types", :aggregate_failures do
      options = helper.body_type_options

      expect(options.map(&:last)).to eq(ApiRequest::BODY_TYPES)
      expect(options.map(&:first)).to all(be_a(String))
    end
  end

  describe "#method_options" do
    it "pairs each method with itself" do
      expect(helper.method_options).to eq(ApiRequest::METHODS.map { |m| [m, m] })
    end
  end
end
