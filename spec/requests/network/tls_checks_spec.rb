require "rails_helper"

RSpec.describe "Network TLS checks" do
  include_context "with workbench project"

  let(:root) { tls_root }

  def session(*chain, version: "TLSv1.3")
    Network::Tls::Handshake::Session.new(version:, cipher: "TLS_AES_256_GCM_SHA384", bits: 256, alpn: "h2", chain: chain.presence || [tls_certificate(issuer: root), root])
  end

  def create_tls_check(host: "example.com", port: "", protocol: "tls")
    post network_tls_checks_path, params: { tls_check: { host:, port:, protocol: } }, headers: turbo_headers
    follow_redirect! if response.location.to_s.include?("/network/checks/")
  end

  before do
    allow(Network::Destination).to receive(:call).and_return(Result.success("203.0.113.9"))
    allow(Network::Tls::Handshake).to receive(:call).and_return(session)
    allow(Network::Tls::Trust).to receive(:default_store).and_return(tls_store(root))
  end

  it "requires authentication" do
    sign_out user
    create_tls_check

    expect(response).to redirect_to(new_user_session_path)
  end

  it "saves the run and shows the certificate at its own address", :aggregate_failures do
    post network_tls_checks_path, params: { tls_check: { host: "example.com", port: "", protocol: "tls" } }, headers: turbo_headers

    expect(response).to redirect_to(network_check_path(project.network_checks.last))
    follow_redirect!

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("tls_result", "203.0.113.9:443", "www.example.com", "Shango Test Root", "TLS_AES_256_GCM_SHA384 (256 bits)", "h2")
    expect(response.body).to include(I18n.t("network.statuses.trusted"), I18n.t("network.statuses.match"), I18n.t("network.statuses.valid"), I18n.t("network.tls.no_findings"))
    expect(response.body).to include(I18n.t("network.tls.issued_by", issuer: "Shango Test Root"), I18n.t("network.tls.self_signed"))
    expect(project.network_checks.last).to have_attributes(kind: "tls", target: "example.com", outcome: "ok", input: { "host" => "example.com", "port" => "", "protocol" => "tls" })
  end

  it "shows what is wrong with a bad certificate and keeps the run as bad", :aggregate_failures do
    allow(Network::Tls::Handshake).to receive(:call).and_return(session(tls_certificate(names: %w[other.example.com], not_before: 1.year.ago, not_after: 2.days.ago), version: "TLSv1"))
    create_tls_check

    expect(response.body).to include(I18n.t("network.statuses.untrusted"), I18n.t("network.statuses.mismatch"), I18n.t("network.statuses.expired"))
    expect(response.body).to include(I18n.t("network.tls.findings.name_mismatch", host: "example.com"), I18n.t("network.tls.findings.untrusted.self_signed"))
    expect(response.body).to include(I18n.t("network.tls.findings.old_protocol", version: "TLSv1"))
    expect(project.network_checks.last.outcome).to eq("bad")
  end

  it "lists the names a certificate covers beyond those kept" do
    stub_const("Network::Tls::Certificate::MAX_NAMES", 1)
    create_tls_check

    expect(response.body).to include(I18n.t("network.tls.names_truncated", shown: 1, total: 2))
  end

  it "leaves out the names section when the certificate has none, and shows missing values as a dash", :aggregate_failures do
    allow(Network::Tls::Handshake).to receive(:call).and_return(Network::Tls::Handshake::Session.new(version: "TLSv1.2", cipher: "AES128-SHA", bits: nil, alpn: nil, chain: [tls_certificate(issuer: root, names: [])]))
    create_tls_check(host: "203.0.113.9")

    expect(response.body).not_to include(I18n.t("network.tls.names_title", total: 0))
    expect(response.body).to include(">AES128-SHA<", "—")
  end

  it "connects with STARTTLS on the usual port of the protocol and reads variables", :aggregate_failures do
    environment = create(:environment, project:)
    create(:variable, environment:, key: "mail", value: "mx.example.com")
    membership.update!(current_environment: environment)
    create_tls_check(host: "{{mail}}", protocol: "smtp")

    expect(Network::Tls::Handshake).to have_received(:call).with(ip: "203.0.113.9", port: 587, sni: "mx.example.com", protocol: "smtp", timeout: Network::TlsChecks::Run::TIMEOUT)
    expect(response.body).to include(I18n.t("network.tls.protocols.smtp"))
    expect(project.network_checks.last.input).to include("host" => "{{mail}}")
  end

  it "still shows the result in place when the run cannot be saved", :aggregate_failures do
    allow(Network::Checks::Record).to receive(:call).and_return(Result.failure(error: :not_saved))
    create_tls_check

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(response.body).to include("tls_result")
  end

  it "answers 422 with the error for invalid input", :aggregate_failures do
    expect { create_tls_check(port: "0") }.not_to change(NetworkCheck, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(I18n.t("network.errors.invalid_port"))
  end

  it "answers 422 with the reason when the handshake fails", :aggregate_failures do
    allow(Network::Tls::Handshake).to receive(:call).and_raise(Network::Tls::Handshake::Failed, "wrong version number")
    create_tls_check(port: "80")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(I18n.t("network.errors.handshake_failed", detail: "wrong version number"))
  end

  describe "throttling" do
    before do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      stub_const("ENV", ENV.to_h.merge("SHANGO_RATE_LIMIT_NETWORK" => "1/60"))
    end

    it "answers into the TLS result area once the limit is hit", :aggregate_failures do
      2.times { create_tls_check }

      expect(response).to have_http_status(:too_many_requests)
      expect(response.body).to include("tls_result", I18n.t("throttling.limited"))
    end
  end

  it "logs who checked which host, port and protocol" do
    allow(Rails.logger).to receive(:info)
    create_tls_check

    expect(Rails.logger).to have_received(:info).with(a_string_matching(/\[network\] tls_check user=#{user.id} project=#{project.id} input="example.com" outcome=ok host=example.com port=443 protocol=tls/))
  end
end
