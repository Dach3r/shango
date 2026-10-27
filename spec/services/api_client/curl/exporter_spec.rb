require "rails_helper"

RSpec.describe ApiClient::Curl::Exporter do
  def body(**attrs)
    ApiClient::RequestBuilder::Body.new(factory: -> { }, multipart: false, **attrs)
  end

  def built(**attrs)
    ApiClient::RequestBuilder::Built.new(
      { http_method: "GET", url: "https://api.example.com", headers: {}, body: body, timeout: 30, follow_redirects: false, verify_ssl: true, defaults_added: [] }.merge(attrs)
    )
  end

  def export(**attrs)
    described_class.call(built: built(**attrs))
  end

  it "renders a bare GET with a timeout" do
    expect(export).to eq("curl \\\n  'https://api.example.com' \\\n  --max-time 30")
  end

  it "adds the method, explicit headers, -k and -L", :aggregate_failures do
    curl = export(
      http_method: "DELETE", headers: { "X-Id" => "1", "Accept" => "*/*" }, defaults_added: ["Accept"], verify_ssl: false, follow_redirects: true
    )

    expect(curl).to include("-X DELETE", "-H 'X-Id: 1'", "-k", "-L")
    expect(curl).not_to include("Accept")
  end

  it "renders raw bodies and escapes quotes" do
    expect(export(body: body(raw: "it's"))).to include("--data-raw 'it'\\''s'")
  end

  it "renders form bodies" do
    expect(export(body: body(form: [["a", "1"], ["file", "@x.txt"]]))).to include("-F 'a=1'", "-F 'file=@x.txt'")
  end

  it "renders binary bodies from the preview" do
    expect(export(body: body(preview: "[binary]"))).to include("--data-binary '@file'")
  end

  describe "shell escaping" do
      it "keeps newlines, double quotes, dollars and backticks inside single quotes" do
        curl = export(body: body(raw: "a\nb'c\"$x`y`\\"))

        expect(curl).to include("--data-raw 'a\nb'\\''c\"$x`y`\\'")
      end

      it "escapes quotes in headers and urls", :aggregate_failures do
        curl = export(url: "https://a.test/?q='x'", headers: { "X-A" => "it's" })

        expect(curl).to include("'https://a.test/?q='\\''x'\\'''", "-H 'X-A: it'\\''s'")
      end

      it "keeps unicode" do
        expect(export(body: body(raw: "héllo ✓"))).to include("'héllo ✓'")
      end

      it "renders empty form values and skips empty raw bodies", :aggregate_failures do
        expect(export(body: body(form: [["a", nil]]))).to include("-F 'a='")
        expect(export(body: body(raw: ""))).not_to include("--data")
      end

      it "round-trips through the parser", :aggregate_failures do
        curl = export(http_method: "POST", body: body(raw: '{"a":"it\'s"}'), headers: { "X-A" => "it's" })
        parsed = ApiClient::Curl::Parser.call(command: curl).record

        expect(parsed).to include(http_method: "POST", body: '{"a":"it\'s"}')
        expect(parsed[:headers]).to contain_exactly(include("key" => "X-A", "value" => "it's"))
      end
    end
end
