require "rails_helper"

RSpec.describe ApiClient::Curl::Parser do
  def parse(command)
    described_class.call(command:)
  end

  def attrs(command)
    parse(command).record
  end

  it "parses a simple GET" do
    expect(attrs("curl https://api.example.com/items?page=2&q=a%20b")).to include(
      name: "GET api.example.com/items", http_method: "GET", url: "https://api.example.com/items?page=2&q=a%20b", body_type: "none", auth_type: "inherit",
      query_params: [
        { "key" => "page", "value" => "2", "enabled" => true, "description" => "" },
        { "key" => "q", "value" => "a b", "enabled" => true, "description" => "" }
      ]
    )
  end

  it "fails on an empty command" do
    result = parse("  ")

    expect(result).to be_failure
    expect(result.error).to eq(I18n.t("workbench.curl.empty"))
  end

  it "fails without a URL" do
    expect(parse("curl -X POST").error).to eq(I18n.t("workbench.curl.missing_url"))
  end

  it "fails when a flag misses its argument" do
    expect(parse("curl https://x.test -H").error).to eq(I18n.t("workbench.curl.missing_argument", flag: "-H"))
  end

  it "fails on unbalanced quotes" do
    expect(parse("curl 'https://x.test").failure?).to be(true)
  end

  it "joins line continuations and expands short flags", :aggregate_failures do
    result = attrs("curl -sSLk \\\n -XPOST -m 2.2 --url https://x.test -H 'X-A: 1' -H bogus")

    expect(result).to include(http_method: "POST", headers: [{ "key" => "X-A", "value" => "1", "enabled" => true, "description" => "" }])
    expect(result[:settings]).to eq("verify_ssl" => false, "follow_redirects" => true, "timeout" => 3)
  end

  it "stops short-flag expansion at the first flag taking an argument" do
    expect(attrs("curl -sH 'X-A: 1' https://x.test")[:headers].first).to include("key" => "X-A")
  end

  it "keeps a lone dash as the URL and the first URL when several are given" do
    expect(attrs("curl - https://other.test")[:url]).to eq("-")
  end

  it "parses explicit headers, user agent, referer and cookies" do
    result = attrs("curl https://x.test -A agent -e http://ref -b a=1 -H 'Content-Type: text/plain'")

    expect(result[:headers].map { |row| row["key"] }).to contain_exactly("Content-Type", "User-Agent", "Referer", "Cookie")
  end

  it "uses basic auth from -u" do
    expect(attrs("curl -u me:secret:x https://x.test")).to include(auth_type: "basic", auth_config: { "username" => "me", "password" => "secret:x" })
  end

  it "infers HEAD, GET and POST methods", :aggregate_failures do
    expect(attrs("curl -I https://x.test")[:http_method]).to eq("HEAD")
    expect(attrs("curl -G https://x.test")[:http_method]).to eq("GET")
    expect(attrs("curl -d a=1 https://x.test")[:http_method]).to eq("POST")
    expect(attrs("curl -F a=1 https://x.test")[:http_method]).to eq("POST")
  end

  it "falls back to GET for unsupported methods" do
    expect(attrs("curl -X purge https://x.test")[:http_method]).to eq("GET")
  end

  it "moves -G data into the query string", :aggregate_failures do
    expect(attrs("curl -G -d a=1 https://x.test")[:url]).to eq("https://x.test?a=1")
    expect(attrs("curl -G -d a=1 https://x.test?b=2")[:url]).to eq("https://x.test?b=2&a=1")
  end

  it "encodes --data-urlencode values", :aggregate_failures do
    expect(attrs("curl --data-urlencode 'a=b c' https://x.test")[:body_form]).to contain_exactly(include("key" => "a", "value" => "b c"))
    expect(attrs("curl --data-urlencode 'b c' https://x.test")[:body_form]).to contain_exactly(include("key" => "b c"))
    expect(attrs("curl --data-urlencode '=b c' https://x.test")[:body_form]).to contain_exactly(include("key" => "b c"))
  end

  it "classifies JSON bodies and drops the implied content type", :aggregate_failures do
    by_flag = attrs("curl --json 'plain' https://x.test")
    by_header = attrs(%q(curl -H 'Content-Type: application/json; charset=utf-8' -d '{"a":1}' https://x.test))
    by_content = attrs(%q(curl -d '{"a":1}' https://x.test))

    expect(by_flag).to include(body_type: "json", body: "plain")
    expect(by_header).to include(body_type: "json", headers: [])
    expect(by_content).to include(body_type: "json", body: '{"a":1}')
  end

  it "does not treat invalid or empty JSON as JSON", :aggregate_failures do
    expect(attrs("curl -d '{bad' https://x.test")[:body_type]).to eq("form_urlencoded")
    expect(attrs("curl -d '{}' https://x.test")[:body_type]).to eq("form_urlencoded")
  end

  it "classifies XML, text and form bodies", :aggregate_failures do
    expect(attrs("curl -H 'Content-Type: text/xml' -d '<a/>' https://x.test")[:body_type]).to eq("xml")
    expect(attrs("curl -H 'Content-Type: text/csv' -d 'a,b' https://x.test")[:body_type]).to eq("text")
    expect(attrs("curl -H 'Content-Type: application/x-www-form-urlencoded' -d 'a=1&b=2' https://x.test")).to include(
      body_type: "form_urlencoded", headers: [], body_form: [include("key" => "a", "value" => "1"), include("key" => "b", "value" => "2")]
    )
  end

  it "falls back to text when the form body cannot be decoded" do
    allow(URI).to receive(:decode_www_form).and_raise(ArgumentError)

    expect(attrs("curl -d 'a=1' https://x.test")).to include(body_type: "text", body: "a=1")
  end

  it "parses multipart form fields" do
    result = attrs("curl -F 'name=Ada' -F 'file=@photo.png' https://x.test")

    expect(result).to include(body_type: "multipart", headers: [])
    expect(result[:body_form]).to contain_exactly(
      include("key" => "name", "value" => "Ada", "type" => "text"),
      include("key" => "file", "value" => "photo.png", "type" => "file")
    )
  end

  it "handles URLs without query, with fragments and variables", :aggregate_failures do
    expect(attrs("curl https://x.test/a#frag?x=1")[:query_params]).to eq([])
    expect(attrs("curl 'https://x.test/?a=&&b={{v}}'")[:query_params].map { |row| [row["key"], row["value"]] }).to eq([["a", ""], ["b", "{{v}}"]])
  end

  it "truncates long names" do
    expect(attrs("curl https://x.test/#{"a" * 100}")[:name].length).to eq(80)
  end

  it "ignores unknown flags" do
    expect(attrs("curl -s https://x.test")[:url]).to eq("https://x.test")
  end
end
