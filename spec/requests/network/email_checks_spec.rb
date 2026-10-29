require "rails_helper"

RSpec.describe "Network email checks" do
  include_context "with workbench project"

  def answer(*records, status: records.empty? ? :nodata : :ok)
    Network::Dns::Query::Answer.new(status:, answers: records, ttl: 60, ms: 1)
  end

  def create_email_check(domain: "example.com")
    post network_email_checks_path, params: { email_check: { domain: } }, headers: turbo_headers
    follow_redirect! if response.location.to_s.include?("/network/checks/")
  end

  let(:records) do
    {
      ["example.com", "TXT"] => answer("v=spf1 include:_spf.example.net -all"),
      ["_spf.example.net", "TXT"] => answer("v=spf1 ip4:203.0.113.0/24 -all"),
      ["_dmarc.example.com", "TXT"] => answer("v=DMARC1; p=reject; rua=mailto:dmarc@example.com"),
      ["example.com", "MX"] => answer("10 mx.example.com"),
      ["mx.example.com", "A"] => answer("203.0.113.5"),
      ["selector1._domainkey.example.com", "TXT"] => answer("v=DKIM1; k=rsa; p=#{Base64.strict_encode64(OpenSSL::PKey::RSA.new(2048).public_to_der)}")
    }
  end

  before { allow(Network::Dns::Lookup).to receive(:call) { |name, type| records.fetch([name, type]) { answer } } }

  it "requires authentication" do
    sign_out user
    create_email_check

    expect(response).to redirect_to(new_user_session_path)
  end

  it "saves the run and shows each part at its own address", :aggregate_failures do
    post network_email_checks_path, params: { email_check: { domain: "example.com selector1" } }, headers: turbo_headers

    expect(response).to redirect_to(network_check_path(project.network_checks.last))
    follow_redirect!

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("email_result", "v=spf1 include:_spf.example.net -all", "v=DMARC1; p=reject", "mx.example.com", "selector1", "rsa 2048", I18n.t("network.email.no_findings"))
    expect(response.body).to include(I18n.t("network.statuses.healthy"), I18n.t("network.email.mx.statuses.ok"), "1 / 10")
    expect(project.network_checks.last).to have_attributes(kind: "email", target: "example.com", outcome: "ok", input: { "domain" => "example.com", "selectors" => "selector1" })
  end

  it "shows what is wrong and keeps the run as bad", :aggregate_failures do
    records.delete(["example.com", "TXT"])
    records.delete(["selector1._domainkey.example.com", "TXT"])
    records[["_dmarc.example.com", "TXT"]] = answer("v=DMARC1; p=reject; pct=50; rua=mailto:dmarc@example.com")
    create_email_check

    expect(response.body).to include(I18n.t("network.email.findings.spf.missing"), I18n.t("network.email.findings.dmarc.partial", pct: "50"), I18n.t("network.email.findings.dkim.none_found"))
    expect(response.body).to include(I18n.t("network.statuses.missing"), I18n.t("network.statuses.attention"), I18n.t("network.email.dkim.none_probed"))
    expect(project.network_checks.last.outcome).to eq("bad")
  end

  it "names the probing of common selectors and where an inherited DMARC record was found", :aggregate_failures do
    records[["_dmarc.example.com", "TXT"]] = answer("v=DMARC1; p=reject; rua=mailto:a@example.com")
    records[["default._domainkey.mail.example.com", "TXT"]] = answer("v=DKIM1; p=")
    records[["mail.example.com", "MX"]] = answer("0 .")
    create_email_check(domain: "mail.example.com")

    expect(response.body).to include(I18n.t("network.email.dkim.probed", count: Network::EmailChecks::Dkim::COMMON_SELECTORS.size), I18n.t("network.email.dkim.statuses.revoked"))
    expect(response.body).to include(I18n.t("network.email.dmarc.inherited", domain: "example.com"), I18n.t("network.email.mx.no_mail"))
  end

  it "reads variables in the domain", :aggregate_failures do
    environment = create(:environment, project:)
    create(:variable, environment:, key: "site", value: "example.com")
    membership.update!(current_environment: environment)
    create_email_check(domain: "{{site}}")

    expect(response.body).to include("v=spf1")
    expect(project.network_checks.last.input).to include("domain" => "{{site}}")
  end

  it "still shows the result in place when the run cannot be saved", :aggregate_failures do
    allow(Network::Checks::Record).to receive(:call).and_return(Result.failure(error: :not_saved))
    create_email_check

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(response.body).to include("email_result")
  end

  it "answers 422 with the error for invalid input", :aggregate_failures do
    expect { create_email_check(domain: "203.0.113.9") }.not_to change(NetworkCheck, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(I18n.t("network.errors.domain_needed"))
  end

  it "names the selector that is not valid", :aggregate_failures do
    create_email_check(domain: "example.com bad!name")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(ERB::Util.html_escape(I18n.t("network.errors.invalid_selector", token: "bad!name")))
  end

  describe "throttling" do
    before do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      stub_const("ENV", ENV.to_h.merge("SHANGO_RATE_LIMIT_NETWORK" => "1/60"))
    end

    it "answers into the email result area once the limit is hit", :aggregate_failures do
      2.times { create_email_check }

      expect(response).to have_http_status(:too_many_requests)
      expect(response.body).to include("email_result", I18n.t("throttling.limited"))
    end
  end

  it "logs who checked which domain" do
    allow(Rails.logger).to receive(:info)
    create_email_check

    expect(Rails.logger).to have_received(:info).with(a_string_matching(/\[network\] email_check user=#{user.id} project=#{project.id} input="example.com" outcome=ok host=example.com/))
  end
end
