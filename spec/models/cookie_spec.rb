require "rails_helper"

RSpec.describe Cookie do
  subject(:cookie) { create(:cookie) }

  it { is_expected.to validate_presence_of(:name) }

  it "encrypts the value" do
    expect(cookie.value_before_type_cast).not_to eq("abc123")
  end

  describe ".live and .expired" do
    it "splits cookies by expiry", :aggregate_failures do
      session = create(:cookie)
      fresh = create(:cookie, expires_at: 1.day.from_now)
      stale = create(:cookie, expires_at: 1.day.ago)

      expect(described_class.live).to contain_exactly(session, fresh)
      expect(described_class.expired).to contain_exactly(stale)
    end
  end

  describe ".for_jar" do
    it "scopes by project and environment, with nil meaning no environment", :aggregate_failures do
      project = create(:project)
      environment = create(:environment, project:)
      bare = create(:cookie, project:)
      scoped = create(:cookie, project:, environment:)
      create(:cookie)

      expect(described_class.for_jar(project, nil)).to contain_exactly(bare)
      expect(described_class.for_jar(project, environment)).to contain_exactly(scoped)
    end
  end

  describe "#matches?" do
    def uri(url)
      URI.parse(url)
    end

    it "matches the host and path", :aggregate_failures do
      cookie = build(:cookie, domain: "api.example.com", path: "/v1")

      expect(cookie.matches?(uri("https://api.example.com/v1"))).to be(true)
      expect(cookie.matches?(uri("https://api.example.com/v1/items"))).to be(true)
      expect(cookie.matches?(uri("https://api.example.com/v10"))).to be(false)
      expect(cookie.matches?(uri("https://api.example.com"))).to be(false)
      expect(cookie.matches?(uri("https://other.example.com/v1"))).to be(false)
    end

    it "matches any path under a trailing slash path and the root" do
      expect(build(:cookie, path: "/a/").matches?(uri("https://api.example.com/a/b"))).to be(true)
      expect(build(:cookie, path: "/").matches?(uri("https://api.example.com"))).to be(true)
    end

    it "matches subdomains only when the cookie is not host only", :aggregate_failures do
      expect(build(:cookie, domain: "example.com", host_only: false).matches?(uri("https://api.example.com/"))).to be(true)
      expect(build(:cookie, domain: "example.com", host_only: true).matches?(uri("https://api.example.com/"))).to be(false)
    end

    it "sends secure cookies over https only", :aggregate_failures do
      cookie = build(:cookie, secure: true)

      expect(cookie.matches?(uri("https://api.example.com/"))).to be(true)
      expect(cookie.matches?(uri("http://api.example.com/"))).to be(false)
    end
  end
end
