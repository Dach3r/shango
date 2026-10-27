require "rails_helper"

RSpec.describe ApiClient::Executor do
  let(:url) { "https://api.example.com/items" }
  let(:body) { ApiClient::RequestBuilder::Body.new(factory: -> { }, multipart: false) }
  let(:auth) { ApiClient::Auth::None.new({}) }
  let(:options) { {} }
  let(:built) do
    ApiClient::RequestBuilder::Built.new(
      {
        http_method: "GET", url:, headers: { "Accept" => "*/*" }, body:, timeout: 5, follow_redirects: true, max_redirects: 5, verify_ssl: true, auth:,
        unresolved: [], secrets: [], defaults_added: []
      }.merge(options)
    )
  end
  let(:reply) { described_class.call(built:) }

  describe "successful calls" do
    it "returns the response", :aggregate_failures do
      stub_request(:get, url).to_return(status: 200, body: "hello", headers: { "Content-Type" => "text/plain" })

      expect(reply).to have_attributes(status: 200, status_text: "OK", body: "hello", content_type: "text/plain", size_bytes: 5, truncated: false, final_url: url, redirects: [])
      expect(reply.error?).to be(false)
      expect(reply.headers).to include(["content-type", "text/plain"])
      expect(reply.sent_headers).to eq([["Accept", "*/*"]])
    end

    it "reports the time spent in each phase", :aggregate_failures do
      stub_request(:get, url).to_return(status: 200, body: "hello")

      expect(reply.timings.keys).to eq(%w[dns tcp tls ttfb download process])
      expect(reply.timings.values).to all(be >= 0)
    end

    it "uses the server reason phrase when present" do
      stub_request(:get, url).to_return(status: [200, "Fine"])

      expect(reply.status_text).to eq("Fine")
    end

    it "sends the request body" do
      options.merge!(http_method: "POST", body: ApiClient::RequestBuilder::Body.new(factory: -> { "payload" }, multipart: false))
      stub = stub_request(:post, url).with(body: "payload").to_return(status: 201)

      expect(reply.status).to eq(201)
      expect(stub).to have_been_requested
    end

    it "sends multipart bodies" do
      options.merge!(
        http_method: "POST", headers: { "Content-Type" => "multipart/form-data" },
        body: ApiClient::RequestBuilder::Body.new(factory: -> { { "a" => "1" } }, multipart: true)
      )
      stub = stub_request(:post, url).with(headers: { "Content-Type" => /multipart/ }).to_return(status: 200)

      expect(reply.status).to eq(200)
      expect(stub).to have_been_requested
    end
  end

  describe "response bodies" do
    it "returns an empty body as an empty string", :aggregate_failures do
      stub_request(:get, url).to_return(status: 204)

      expect(reply).to have_attributes(status: 204, body: "", size_bytes: 0, truncated: false)
    end

    it "keeps binary bodies byte for byte", :aggregate_failures do
      payload = (0..255).map(&:chr).join.b
      stub_request(:get, url).to_return(status: 200, body: payload, headers: { "Content-Type" => "application/octet-stream" })

      expect(reply.body).to eq(payload)
      expect(reply.size_bytes).to eq(256)
    end

    it "keeps bodies that are not valid UTF-8 untouched" do
      stub_request(:get, url).to_return(status: 200, body: "caf\xE9".b)

      expect(reply.body.bytes).to eq("caf\xE9".b.bytes)
    end

    it "does not truncate a body of exactly the limit", :aggregate_failures do
      stub_request(:get, url).to_return(status: 200, body: "a" * described_class::MAX_RESPONSE_BYTES)

      expect(reply).to have_attributes(truncated: false, size_bytes: described_class::MAX_RESPONSE_BYTES)
    end

    it "reads responses without a status text or with an unknown status code", :aggregate_failures do
      stub_request(:get, url).to_return(status: [599, ""])

      expect(reply).to have_attributes(status: 599, status_text: nil, error_kind: nil)
    end

    it "returns error statuses as responses, not errors", :aggregate_failures do
      stub_request(:get, url).to_return(status: 503, body: "down")

      expect(reply).to have_attributes(status: 503, status_text: "Service Unavailable", body: "down", error_kind: nil)
    end

    it "returns no body for a HEAD request" do
      options.merge!(http_method: "HEAD")
      stub_request(:head, url).to_return(status: 200, headers: { "Content-Length" => "10" })

      expect(reply).to have_attributes(status: 200, body: "")
    end
  end

  describe "large responses" do
    it "truncates bodies over the limit", :aggregate_failures do
      stub_request(:get, url).to_return(status: 200, body: "a" * (described_class::MAX_RESPONSE_BYTES + 10))

      expect(reply.truncated).to be(true)
      expect(reply.body.bytesize).to eq(described_class::MAX_RESPONSE_BYTES)
      expect(reply.size_bytes).to eq(described_class::MAX_RESPONSE_BYTES)
      expect(reply.status).to eq(200)
    end
  end

  describe "response cookies" do
    it "lists each Set-Cookie of the final response", :aggregate_failures do
      stub_request(:get, url).to_return(status: 200, headers: { "Set-Cookie" => ["a=1; Path=/", "b=2; Path=/"] })

      expect(reply.set_cookies).to eq(["a=1; Path=/", "b=2; Path=/"])
    end

    it "has none when the request fails" do
      stub_request(:get, url).to_raise(Errno::ECONNREFUSED)

      expect(reply.set_cookies).to eq([])
    end
  end

  describe "cookie jar" do
    let(:project) { create(:project) }
    let(:jar) { ApiClient::CookieJar.new(project:) }
    let(:reply) { described_class.call(built:, cookie_jar: jar) }

    it "sends stored cookies and keeps the ones the response sets", :aggregate_failures do
      jar.store(url, "stored=1; Path=/")
      stub = stub_request(:get, url).with(headers: { "Cookie" => "stored=1" }).to_return(status: 200, headers: { "Set-Cookie" => "fresh=2; Path=/" })

      expect(reply.sent_headers).to include(["Cookie", "stored=1"])
      expect(stub).to have_been_requested
      expect(jar.header(url)).to eq("stored=1; fresh=2")
    end

    it "lets a typed Cookie header win over stored cookies of the same name", :aggregate_failures do
      jar.store(url, "a=stored; Path=/")
      jar.store(url, "b=stored; Path=/")
      options.merge!(headers: { "cookie" => "a=typed" })
      stub = stub_request(:get, url).with(headers: { "Cookie" => "a=typed; b=stored" }).to_return(status: 200)

      reply

      expect(stub).to have_been_requested
    end

    it "keeps the typed header as is when every stored cookie is overridden", :aggregate_failures do
      jar.store(url, "a=stored; Path=/")
      options.merge!(headers: { "Cookie" => "a=typed" })
      stub = stub_request(:get, url).with(headers: { "Cookie" => "a=typed" }).to_return(status: 200)

      reply

      expect(stub).to have_been_requested
    end

    it "carries cookies through redirects", :aggregate_failures do
      target = "https://api.example.com/final"
      stub_request(:get, url).to_return(status: 302, headers: { "Location" => "/final", "Set-Cookie" => "session=abc; Path=/" })
      stub = stub_request(:get, target).with(headers: { "Cookie" => "session=abc" }).to_return(status: 200)

      expect(reply.status).to eq(200)
      expect(stub).to have_been_requested
    end

    it "does not touch requests when no cookie applies" do
      stub = stub_request(:get, url).with { |request| !request.headers.key?("Cookie") }.to_return(status: 200)

      reply

      expect(stub).to have_been_requested
    end
  end

  describe "redirects" do
    let(:target) { "https://api.example.com/final" }

    it "follows redirects, resolving relative locations", :aggregate_failures do
      stub_request(:get, url).to_return(status: 302, headers: { "Location" => "/final" })
      stub_request(:get, target).to_return(status: 200, body: "done")

      expect(reply).to have_attributes(status: 200, final_url: target, redirects: [{ "status" => 302, "from" => url, "to" => target }])
    end

    it "turns POST into GET and drops the body headers on 302/303", :aggregate_failures do
      options.merge!(
        http_method: "POST", headers: { "Content-Type" => "application/json", "Content-Length" => "2", "X-Keep" => "1" },
        body: ApiClient::RequestBuilder::Body.new(factory: -> { "{}" }, multipart: false)
      )
      stub_request(:post, url).to_return(status: 303, headers: { "Location" => target })
      stub = stub_request(:get, target).with { |request| request.body.blank? && request.headers.key?("X-Keep") && !request.headers.key?("Content-Type") }.to_return(status: 200)

      expect(reply.status).to eq(200)
      expect(stub).to have_been_requested
    end

    it "keeps method and body on 307" do
      options.merge!(http_method: "POST", body: ApiClient::RequestBuilder::Body.new(factory: -> { "x" }, multipart: false))
      stub_request(:post, url).to_return(status: 307, headers: { "Location" => target })
      stub = stub_request(:post, target).with(body: "x").to_return(status: 200)

      reply

      expect(stub).to have_been_requested
    end

    it "keeps HEAD on 303" do
      options.merge!(http_method: "HEAD")
      stub_request(:head, url).to_return(status: 303, headers: { "Location" => target })
      stub = stub_request(:head, target).to_return(status: 200)

      reply

      expect(stub).to have_been_requested
    end

    it "drops credentials when the redirect leaves the origin", :aggregate_failures do
      options.merge!(headers: { "Authorization" => "Bearer abc", "Cookie" => "a=1", "X-Keep" => "1" })
      stub_request(:get, url).to_return(status: 301, headers: { "Location" => "https://other.example.com/final" })
      stub = stub_request(:get, "https://other.example.com/final").with { |request| request.headers.key?("X-Keep") && !request.headers.key?("Authorization") && !request.headers.key?("Cookie") }.to_return(status: 200)

      expect(reply.status).to eq(200)
      expect(stub).to have_been_requested
    end

    it "keeps credentials on same-origin redirects" do
      options.merge!(headers: { "Authorization" => "Bearer abc" })
      stub_request(:get, url).to_return(status: 302, headers: { "Location" => target })
      stub = stub_request(:get, target).with(headers: { "Authorization" => "Bearer abc" }).to_return(status: 200)

      reply

      expect(stub).to have_been_requested
    end

    it "does not follow when disabled" do
      options.merge!(follow_redirects: false)
      stub_request(:get, url).to_return(status: 302, headers: { "Location" => target })

      expect(reply).to have_attributes(status: 302, redirects: [])
    end

    it "does not follow without a location" do
      stub_request(:get, url).to_return(status: 302)

      expect(reply.status).to eq(302)
    end

    it "drops credentials on a redirect to another scheme or port", :aggregate_failures do
      options.merge!(headers: { "Authorization" => "Bearer abc", "X-Api-Key" => "k", "Proxy-Authorization" => "p" })
      stub_request(:get, url).to_return(status: 302, headers: { "Location" => "http://api.example.com/final" })
      stub_request(:get, "http://api.example.com/final").with { |request| request.headers.keys.none? { |name| %w[Authorization X-Api-Key Proxy-Authorization].include?(name) } }.to_return(status: 302, headers: { "Location" => "http://api.example.com:8080/x" })
      stub = stub_request(:get, "http://api.example.com:8080/x").with { |request| !request.headers.key?("Authorization") }.to_return(status: 200)

      expect(reply.status).to eq(200)
      expect(stub).to have_been_requested
    end

    it "treats a protocol relative location as another origin", :aggregate_failures do
      options.merge!(headers: { "Authorization" => "Bearer abc" })
      stub_request(:get, url).to_return(status: 302, headers: { "Location" => "//evil.test/steal" })
      stub = stub_request(:get, "https://evil.test/steal").with { |request| !request.headers.key?("Authorization") }.to_return(status: 200)

      expect(reply.status).to eq(200)
      expect(stub).to have_been_requested
    end

    it "does not send the cookies of one host to the host it redirects to", :aggregate_failures do
      jar = ApiClient::CookieJar.new(project: create(:project))
      jar.store(url, "session=abc; Path=/")
      stub_request(:get, url).to_return(status: 302, headers: { "Location" => "https://other.example.com/x" })
      stub = stub_request(:get, "https://other.example.com/x").with { |request| !request.headers.key?("Cookie") }.to_return(status: 200)

      expect(described_class.call(built:, cookie_jar: jar).status).to eq(200)
      expect(stub).to have_been_requested
    end

    it "follows 301 and 302 of a PUT without changing the method", :aggregate_failures do
      options.merge!(http_method: "PUT", body: ApiClient::RequestBuilder::Body.new(factory: -> { "x" }, multipart: false))
      stub_request(:put, url).to_return(status: 301, headers: { "Location" => target })
      stub = stub_request(:put, target).with(body: "x").to_return(status: 200)

      expect(reply.status).to eq(200)
      expect(stub).to have_been_requested
    end

    it "follows a chain of redirects up to the maximum and records each hop", :aggregate_failures do
      options.merge!(max_redirects: 3)
      (0..2).each { |i| stub_request(:get, "#{url}#{i.positive? ? i : ""}").to_return(status: 302, headers: { "Location" => "#{url}#{i + 1}" }) }
      stub_request(:get, "#{url}3").to_return(status: 200, body: "done")

      expect(reply).to have_attributes(status: 200, body: "done", final_url: "#{url}3")
      expect(reply.redirects.map { |hop| hop["status"] }).to eq([302, 302, 302])
    end

    it "stops a redirect loop at the maximum", :aggregate_failures do
      options.merge!(max_redirects: 4)
      stub_request(:get, url).to_return(status: 302, headers: { "Location" => target })
      stub_request(:get, target).to_return(status: 302, headers: { "Location" => url })

      expect(reply).to have_attributes(status: 302, error_kind: nil)
      expect(reply.redirects.size).to eq(4)
    end

    it "does not follow when the maximum is zero" do
      options.merge!(max_redirects: 0)
      stub_request(:get, url).to_return(status: 302, headers: { "Location" => target })

      expect(reply).to have_attributes(status: 302, redirects: [])
    end

    it "does not follow 300, 304 or 305", :aggregate_failures do
      [300, 304, 305].each do |status|
        stub_request(:get, url).to_return(status:, headers: { "Location" => target })

        expect(described_class.call(built:)).to have_attributes(status:, redirects: [])
      end
    end

    it "reports a location that is not a valid url", :aggregate_failures do
      stub_request(:get, url).to_return(status: 302, headers: { "Location" => "http://[bad" })

      expect(reply).to have_attributes(error_kind: "invalid_url", status: nil, final_url: url)
    end

    it "refuses to be redirected to other schemes", :aggregate_failures do
      ["file:///etc/passwd", "gopher://internal.test/", "ftp://x.test/f"].each do |location|
        stub_request(:get, url).to_return(status: 302, headers: { "Location" => location })

        expect(described_class.call(built:)).to have_attributes(error_kind: "invalid_url", final_url: location)
      end
    end

    it "resolves dot segments and query only locations", :aggregate_failures do
      stub_request(:get, url).to_return(status: 302, headers: { "Location" => "../up?x=1" })
      stub = stub_request(:get, "https://api.example.com/up?x=1").to_return(status: 200)

      expect(reply.final_url).to eq("https://api.example.com/up?x=1")
      expect(stub).to have_been_requested
    end

    it "stops after the maximum number of redirects", :aggregate_failures do
      options.merge!(max_redirects: 1)
      stub_request(:get, url).to_return(status: 302, headers: { "Location" => target })
      stub_request(:get, target).to_return(status: 302, headers: { "Location" => url })

      expect(reply.status).to eq(302)
      expect(reply.redirects.size).to eq(1)
    end
  end

  describe "private network policy" do
    def resolve_hosts(map)
      allow(Addrinfo).to receive(:getaddrinfo) { |host| Array(map.fetch(host) { Addrinfo.ip(host.delete("[]")).ip_address }).map { |ip| instance_double(Addrinfo, ip_address: ip) } }
    end

    before { stub_const("ENV", ENV.to_h.merge("SHANGO_BLOCK_PRIVATE_NETWORKS" => "true")) }

    it "blocks a redirect to a private host without requesting it", :aggregate_failures do
      resolve_hosts("api.example.com" => "93.184.216.34", "internal.test" => "10.0.0.5")
      stub_request(:get, url).to_return(status: 302, headers: { "Location" => "http://internal.test/admin" })
      internal = stub_request(:get, "http://internal.test/admin")

      expect(reply).to have_attributes(error_kind: "blocked", redirects: [include("status" => 302)], final_url: "http://internal.test/admin")
      expect(internal).not_to have_been_requested
    end

    it "blocks a redirect to a loopback or metadata literal", :aggregate_failures do
      resolve_hosts("api.example.com" => "93.184.216.34")
      ["http://127.0.0.1:3000/", "http://[::1]/", "http://169.254.169.254/latest/meta-data/", "http://2130706433/"].each do |location|
        stub_request(:get, url).to_return(status: 301, headers: { "Location" => location })

        expect(described_class.call(built:)).to have_attributes(error_kind: "blocked", final_url: location)
      end
    end

    it "blocks a host that resolves to both a public and a private address" do
      resolve_hosts("api.example.com" => ["93.184.216.34", "192.168.0.10"])

      expect(reply.error_kind).to eq("blocked")
    end

    it "checks the address again on every hop", :aggregate_failures do
      calls = 0
      allow(Addrinfo).to receive(:getaddrinfo) do |host|
        calls += 1
        ip = host == "api.example.com" && calls > 1 ? "127.0.0.1" : "93.184.216.34"
        [instance_double(Addrinfo, ip_address: ip)]
      end
      stub_request(:get, url).to_return(status: 302, headers: { "Location" => "/next" })
      next_stub = stub_request(:get, "https://api.example.com/next")

      expect(reply.error_kind).to eq("blocked")
      expect(next_stub).not_to have_been_requested
    end

    it "lets public hosts through", :aggregate_failures do
      resolve_hosts("api.example.com" => "93.184.216.34")
      stub_request(:get, url).to_return(status: 200, body: "ok")

      expect(reply).to have_attributes(status: 200, error_kind: nil)
    end

    it "blocks userinfo tricks that hide a private host", :aggregate_failures do
      options.merge!(url: "http://api.example.com@127.0.0.1/")

      expect(reply).to have_attributes(error_kind: "blocked", status: nil)
    end

    it "reports unresolvable hosts as dns failures" do
      allow(Addrinfo).to receive(:getaddrinfo).and_raise(Socket::ResolutionError, "no such host")

      expect(reply.error_kind).to eq("dns")
    end
  end

  describe "digest authentication" do
    let(:auth) { ApiClient::Auth::Digest.new({ "username" => "me", "password" => "pw" }) }
    let(:challenge) { 'Digest realm="r", nonce="abc", qop="auth"' }

    it "answers the challenge once", :aggregate_failures do
      stub_request(:get, url).to_return({ status: 401, headers: { "WWW-Authenticate" => challenge } }, { status: 200, body: "ok" })

      expect(reply.status).to eq(200)
      expect(a_request(:get, url).with(headers: { "Authorization" => /\ADigest/ })).to have_been_made.once
      expect(reply.sent_headers.map(&:first)).to include("Authorization")
    end

    it "returns the 401 when the challenge is rejected" do
      stub_request(:get, url).to_return(status: 401, headers: { "WWW-Authenticate" => challenge })

      expect(reply.status).to eq(401)
      expect(a_request(:get, url)).to have_been_made.twice
    end

    it "returns the 401 when it is not a digest challenge" do
      stub_request(:get, url).to_return(status: 401, headers: { "WWW-Authenticate" => "Basic realm=x" })

      expect(reply.status).to eq(401)
      expect(a_request(:get, url)).to have_been_made.once
    end

    it "does not treat 401 as a challenge for other strategies" do
      options.merge!(auth: ApiClient::Auth::None.new({}))
      stub_request(:get, url).to_return(status: 401, headers: { "WWW-Authenticate" => challenge })

      reply

      expect(a_request(:get, url)).to have_been_made.once
    end
  end

  describe "errors" do
    let(:connection) { instance_double(Faraday::Connection) }

    def fail_with(error)
      allow(ApiClient::Connection).to receive(:build).and_return(connection)
      allow(connection).to receive(:run_request).and_raise(error)
    end

    it "reports invalid urls" do
      options.merge!(url: "ftp://x.test")

      expect(reply).to have_attributes(error_kind: "invalid_url", status: nil, body: "", sent_headers: [["Accept", "*/*"]], final_url: "ftp://x.test")
      expect(reply.error?).to be(true)
    end

    it "reports blocked addresses" do
      allow(ApiClient::SsrfPolicy).to receive(:check!).and_raise(ApiClient::SsrfPolicy::Blocked, "private")

      expect(reply).to have_attributes(error_kind: "blocked", error_message: "private")
    end

    it "reports timeouts", :aggregate_failures do
      fail_with(Faraday::TimeoutError.new("slow"))
      expect(reply.error_kind).to eq("timeout")
    end

    it "stops when the total duration is exceeded while reading", :aggregate_failures do
      stub_const("#{described_class}::MAX_DURATION", 0)
      stub_request(:get, url).to_return(status: 200, body: "hello")

      expect(reply).to have_attributes(error_kind: "timeout", error_message: /maximum duration of 0 seconds/)
    end

    it "stops following redirects once the deadline passes mid-call", :aggregate_failures do
      now = 0.0
      allow_any_instance_of(described_class).to receive(:monotonic_now) { now } # rubocop:disable RSpec/AnyInstance
      stub_request(:get, url).to_return { now = 500.0 and { status: 302, headers: { "Location" => "/next" } } }
      next_stub = stub_request(:get, "https://api.example.com/next").to_return(status: 200)

      expect(reply).to have_attributes(error_kind: "timeout")
      expect(next_stub).not_to have_been_requested
    end

    it "caps the attempt timeout to the time left", :aggregate_failures do
      allow(ApiClient::Connection).to receive(:build).and_call_original
      stub_request(:get, url).to_return(status: 200)
      stub_const("#{described_class}::MAX_DURATION", 2)

      reply

      expect(ApiClient::Connection).to have_received(:build).with(hash_including(timeout: 2))
    end

    it "stops when cancelled", :aggregate_failures do
      stub_request(:get, url).to_return(status: 200, body: "hello")

      reply = described_class.call(built:, cancelled: -> { true })

      expect(reply).to have_attributes(error_kind: "cancelled", error_message: "Cancelled")
    end

    it "reports ssl errors" do
      fail_with(Faraday::SSLError.new("bad cert"))

      expect(reply).to have_attributes(error_kind: "ssl", error_message: "bad cert")
    end

    it "reports dns failures", :aggregate_failures do
      fail_with(SocketError.new("no host"))
      expect(reply.error_kind).to eq("dns")
    end

    it "classifies connection failures by cause", :aggregate_failures do
      {
        SocketError.new("dns") => "dns", Errno::ECONNREFUSED.new => "refused", Timeout::Error.new("slow") => "timeout", IOError.new("boom") => "connection"
      }.each do |cause, kind|
        fail_with(Faraday::ConnectionFailed.new(cause))

        expect(described_class.call(built:).error_kind).to eq(kind)
      end
    end

    it "classifies connection failures without a cause" do
      fail_with(Faraday::ConnectionFailed.new("down"))

      expect(reply).to have_attributes(error_kind: "connection", error_message: "down")
    end

    it "does not send headers with line breaks in them", :aggregate_failures do
      options.merge!(headers: { "X-Evil" => "a\r\nX-Injected: 1" })
      stub = stub_request(:get, url)

      expect(reply).to have_attributes(error_kind: "unknown", status: nil)
      expect(stub).not_to have_been_requested
    end

    it "reports unknown errors" do
      fail_with(RuntimeError.new("oops"))

      expect(reply).to have_attributes(error_kind: "unknown", error_message: "RuntimeError: oops")
    end

    it "keeps the redirect trail when a later hop fails" do
      stub_request(:get, url).to_return(status: 302, headers: { "Location" => "/next" })
      stub_request(:get, "https://api.example.com/next").to_timeout

      expect(reply).to have_attributes(error_kind: "timeout", final_url: "https://api.example.com/next", redirects: [include("status" => 302)])
    end

    it "reports errors raised before the state is built", :aggregate_failures do
      allow(built).to receive(:http_method).and_raise("broken")

      expect(reply).to have_attributes(error_kind: "unknown", final_url: url, redirects: [], sent_headers: [["Accept", "*/*"]])
    end
  end
end
