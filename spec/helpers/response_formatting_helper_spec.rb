RSpec.describe ResponseFormattingHelper do
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

  describe "#payload_language" do
    def execution(body, headers = [])
      build(:request_execution, request_body: body, request_headers: headers)
    end

    it "uses the Content-Type header" do
      expect(helper.payload_language(execution("a=1", [["content-type", "application/xml"]]))).to eq("xml")
    end

    it "sniffs JSON, XML and plain text from the body", :aggregate_failures do
      expect(helper.payload_language(execution('{"a":1}'))).to eq("json")
      expect(helper.payload_language(execution("<a/>"))).to eq("xml")
      expect(helper.payload_language(execution("a=1"))).to eq("text")
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
end
