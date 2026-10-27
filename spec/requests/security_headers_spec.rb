require "rails_helper"

RSpec.describe "Security headers" do
  def policy
    response.headers["Content-Security-Policy"]
  end

  it "sends a content security policy on public pages", :aggregate_failures do
    get new_user_session_path

    expect(policy).to include("default-src 'self'", "object-src 'none'", "base-uri 'self'", "frame-ancestors 'none'", "connect-src 'self'")
    expect(policy).not_to include("form-action")
    expect(response.headers).not_to have_key("Content-Security-Policy-Report-Only")
  end

  it "does not allow arbitrary scripts", :aggregate_failures do
    get new_user_session_path

    expect(policy[/script-src [^;]*/]).not_to include("unsafe-inline", "unsafe-eval", "https:")
  end

  it "puts the per-request nonce on the importmap script", :aggregate_failures do
    get new_user_session_path
    nonce = policy[/'nonce-([^']+)'/, 1]

    expect(nonce).to be_present
    expect(response.body).to include(%(<script type="importmap" data-turbo-track="reload" nonce="#{nonce}">))
  end

  it "uses a fresh nonce on each request" do
    get new_user_session_path
    first = policy[/'nonce-([^']+)'/, 1]
    get new_user_session_path

    expect(policy[/'nonce-([^']+)'/, 1]).not_to eq(first)
  end

  it "covers signed-in pages too" do
    sign_in_with_project
    get workbench_root_path

    expect(policy).to include("default-src 'self'")
  end

  it "sends the other hardening headers", :aggregate_failures do
    get new_user_session_path

    expect(response.headers).to include("X-Content-Type-Options" => "nosniff", "X-Frame-Options" => "SAMEORIGIN", "Referrer-Policy" => "strict-origin-when-cross-origin")
    expect(response.headers["Permissions-Policy"]).to include("camera=()", "geolocation=()")
  end

  it "has no inline scripts besides the nonced importmap", :aggregate_failures do
    get new_user_session_path
    scripts = response.body.scan(/<script\b[^>]*>/)

    expect(scripts).to all(match(/nonce=|src=/))
    expect(response.body).not_to match(/\son(click|load|submit|change)=/)
  end
end
