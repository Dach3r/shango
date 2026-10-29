require "rails_helper"

RSpec.describe "Monitoring pushes" do
  let(:token) { "abcDEF123_-xyz" }
  let!(:monitor) { create(:uptime_monitor, :push, push_token_digest: UptimeMonitor.digest(token)) }

  it "takes a ping by GET or POST without a session or CSRF token", :aggregate_failures do
    get monitoring_push_path(token:)
    expect(response).to have_http_status(:no_content)
    expect(monitor.reload).to be_up

    post monitoring_push_path(token:)
    expect(response).to have_http_status(:no_content)
    expect(monitor.check_results.count).to eq(2)
  end

  it "takes the token from a header" do
    post monitoring_push_path, headers: { "X-Shango-Push-Token" => token }

    expect(response).to have_http_status(:no_content)
  end

  it "answers 404 for an unknown or missing token", :aggregate_failures do
    get monitoring_push_path(token: "unknown")
    expect(response).to have_http_status(:not_found)

    post monitoring_push_path
    expect(response).to have_http_status(:not_found)
  end

  it "accepts and ignores a ping to a paused monitor", :aggregate_failures do
    monitor.update!(enabled: false)
    get monitoring_push_path(token:)

    expect(response).to have_http_status(:no_content)
    expect(monitor.check_results).to be_empty
  end

  it "limits pings per token", :aggregate_failures do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    stub_const("ENV", ENV.to_h.merge("SHANGO_RATE_LIMIT_PUSH" => "2/60"))
    3.times { get monitoring_push_path(token:) }

    expect(response).to have_http_status(:too_many_requests)
    expect(response.headers["Retry-After"]).to eq("60")
  end

  it "keeps the token out of the log", :aggregate_failures do
    output = StringIO.new
    logger = ActiveSupport::Logger.new(output)
    allow(Rails).to receive(:logger).and_return(ActiveSupport::BroadcastLogger.new(logger))
    get monitoring_push_path(token:)
    get monitoring_root_path

    expect(output.string).not_to include(token)
    expect(output.string).to include("/monitoring")
  end
end
