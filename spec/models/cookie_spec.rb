require "rails_helper"

RSpec.describe Cookie do
  subject(:cookie) { create(:cookie) }

  it { is_expected.to validate_presence_of(:name) }

  describe "validations" do
    it "requires an absolute path", :aggregate_failures do
      expect(build(:cookie, path: "items")).not_to be_valid
      expect(build(:cookie, path: "/items")).to be_valid
    end

    it "rejects domains with spaces or slashes", :aggregate_failures do
      expect(build(:cookie, domain: "api example.com")).not_to be_valid
      expect(build(:cookie, domain: "api.example.com/path")).not_to be_valid
      expect(build(:cookie, domain: "[::1]")).to be_valid
    end

    it "limits the value length" do
      expect(build(:cookie, value: "x" * (described_class::MAX_VALUE_LENGTH + 1))).not_to be_valid
    end

    it "keeps cookies unique per jar, domain and path", :aggregate_failures do
      first = create(:cookie, name: "a")

      expect(build(:cookie, project: first.project, name: "a")).not_to be_valid
      expect(build(:cookie, project: first.project, name: "a", path: "/other")).to be_valid
      expect(build(:cookie, project: first.project, environment: create(:environment, project: first.project), name: "a")).to be_valid
    end

    it "only shares with subdomains from a domain with a dot that is not an IP", :aggregate_failures do
      expect(build(:cookie, domain: "localhost", host_only: false)).not_to be_valid
      expect(build(:cookie, domain: "127.0.0.1", host_only: false)).not_to be_valid
      expect(build(:cookie, domain: "::1", host_only: false)).not_to be_valid
      expect(build(:cookie, domain: "example.com", host_only: false)).to be_valid
      expect(build(:cookie, domain: "localhost", host_only: true)).to be_valid
    end
  end

  describe ".trim" do
    it "drops the least recently updated cookies over the cap", :aggregate_failures do
      stub_const("Cookie::MAX_PER_JAR", 2)
      project = create(:project)
      oldest = create(:cookie, project:, updated_at: 3.days.ago)
      newer = create(:cookie, project:, updated_at: 1.day.ago)
      newest = create(:cookie, project:)
      foreign = create(:cookie)

      described_class.trim(project, nil)

      expect(described_class.all).to contain_exactly(newer, newest, foreign)
      expect(described_class.exists?(oldest.id)).to be(false)
    end

    it "leaves a jar within the cap alone" do
      project = create(:project)
      create_list(:cookie, 2, project:)

      expect { described_class.trim(project, nil) }.not_to change(described_class, :count)
    end
  end

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
