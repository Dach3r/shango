require "rails_helper"

RSpec.describe ApiClient::CookieJar do
  let(:project) { create(:project) }
  let(:environment) { nil }
  let(:jar) { described_class.new(project:, environment:) }
  let(:url) { "https://api.example.com/v1/sign_in" }

  describe "#store and #header" do
    it "replays a stored cookie on the same host", :aggregate_failures do
      jar.store(url, "_session=abc; Path=/; HttpOnly; Secure")

      expect(jar.header("https://api.example.com/other")).to eq("_session=abc")
      expect(jar.header("https://elsewhere.example.com/")).to be_nil
      expect(Cookie.last).to have_attributes(domain: "api.example.com", path: "/", host_only: true, secure: true, http_only: true, expires_at: nil)
    end

    it "does nothing without a Set-Cookie header" do
      jar.store(url, nil)

      expect(Cookie.count).to eq(0)
    end

    it "splits cookies merged into one header, keeping dates intact", :aggregate_failures do
      jar.store(url, "a=1; Expires=Wed, 21 Oct 2037 07:28:00 GMT; Path=/, b=2; Path=/")

      expect(jar.header(url)).to eq("a=1; b=2")
      expect(Cookie.find_by(name: "a").expires_at).to eq(Time.utc(2037, 10, 21, 7, 28))
    end

    it "overwrites a cookie with the same name, domain and path", :aggregate_failures do
      jar.store(url, "a=1; Path=/")
      jar.store(url, "a=2; Path=/")

      expect(Cookie.count).to eq(1)
      expect(jar.header(url)).to eq("a=2")
    end

    it "defaults the path to the directory of the request", :aggregate_failures do
      jar.store(url, "a=1")
      jar.store("https://api.example.com/sign_in", "b=1")

      expect(Cookie.find_by(name: "a").path).to eq("/v1")
      expect(Cookie.find_by(name: "b").path).to eq("/")
    end

    it "orders longer paths first" do
      jar.store(url, "a=root; Path=/")
      jar.store(url, "b=deep; Path=/v1")

      expect(jar.header(url)).to eq("b=deep; a=root")
    end

    it "removes a cookie the server expires", :aggregate_failures do
      jar.store(url, "a=1; Path=/")
      jar.store(url, "a=; Path=/; Max-Age=0")

      expect(Cookie.count).to eq(0)
      expect(jar.header(url)).to be_nil
    end

    it "ignores cookies already expired and drops stored ones that lapse", :aggregate_failures do
      jar.store(url, "a=1; Path=/; Expires=Wed, 21 Oct 2015 07:28:00 GMT")
      stale = create(:cookie, project:, expires_at: 1.minute.ago)
      jar.store(url, "b=1; Path=/")

      expect(Cookie.where(name: "a")).to be_empty
      expect(Cookie.exists?(stale.id)).to be(false)
    end

    it "honours Max-Age over Expires" do
      jar.store(url, "a=1; Path=/; Max-Age=60; Expires=Wed, 21 Oct 2015 07:28:00 GMT")

      expect(Cookie.find_by(name: "a").expires_at).to be_within(5.seconds).of(1.minute.from_now)
    end

    it "treats an unparsable Expires as a session cookie" do
      jar.store(url, "a=1; Path=/; Expires=2030-13-45")

      expect(Cookie.find_by(name: "a").expires_at).to be_nil
    end

    it "shares cookies set for a parent domain with its subdomains", :aggregate_failures do
      jar.store(url, "a=1; Path=/; Domain=.example.com")

      expect(jar.header("https://www.example.com/")).to eq("a=1")
      expect(Cookie.find_by(name: "a")).to have_attributes(domain: "example.com", host_only: false)
    end

    it "rejects domains the host does not belong to, public suffixes and IPs", :aggregate_failures do
      jar.store(url, "a=1; Domain=other.com")
      jar.store(url, "b=1; Domain=com")
      jar.store("http://10.0.0.1/", "c=1; Domain=0.0.1")

      expect(Cookie.count).to eq(0)
    end

    it "accepts a domain equal to the host" do
      jar.store(url, "a=1; Domain=api.example.com")

      expect(Cookie.count).to eq(1)
    end

    it "ignores malformed and oversized cookies", :aggregate_failures do
      jar.store(url, "=novalue; Path=/")
      jar.store(url, "novalue")
      jar.store(url, "big=#{"x" * 5000}")

      expect(Cookie.count).to eq(0)
    end

    it "ignores cookies with a relative Path attribute" do
      jar.store(url, "a=1; Path=relative")

      expect(Cookie.find_by(name: "a").path).to eq("/v1")
    end

    it "does not send secure cookies over http" do
      jar.store(url, "a=1; Path=/; Secure")

      expect(jar.header("http://api.example.com/")).to be_nil
    end

    it "keeps jars apart by project and environment", :aggregate_failures do
      other_environment = create(:environment, project:)
      jar.store(url, "a=1; Path=/")
      described_class.new(project:, environment: other_environment).store(url, "a=2; Path=/")

      expect(jar.header(url)).to eq("a=1")
      expect(described_class.new(project:, environment: other_environment).header(url)).to eq("a=2")
      expect(described_class.new(project: create(:project)).header(url)).to be_nil
    end

    it "evicts the least recently updated cookies over the limit", :aggregate_failures do
      stub_const("Cookie::MAX_PER_JAR", 2)
      jar.store(url, "a=1; Path=/")
      Cookie.update_all(updated_at: 1.day.ago)
      jar.store(url, "b=1; Path=/")
      jar.store(url, "c=1; Path=/")

      expect(Cookie.pluck(:name)).to contain_exactly("b", "c")
    end

    it "ignores invalid URLs", :aggregate_failures do
      jar.store("http://bad host/", "a=1")

      expect(Cookie.count).to eq(0)
      expect(jar.header("http://bad host/")).to be_nil
    end
  end
end
