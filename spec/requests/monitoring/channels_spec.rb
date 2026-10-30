require "rails_helper"

RSpec.describe "Monitoring channels" do
  include ActiveJob::TestHelper

  let(:context) { sign_in_with_project }
  let(:user) { context[0] }
  let(:project) { context[1] }
  let(:membership) { context[2] }

  before { context }

  # SMTP configured, without asking the signed-in user to confirm their email.
  def enable_mail
    allow(Shango::Mailing).to receive_messages(enabled?: true, confirmation_required?: false)
  end

  describe "index" do
    it "shows an empty state", :aggregate_failures do
      get monitoring_channels_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("monitoring.channels.index.empty"), new_monitoring_channel_path, I18n.t("monitoring.tabs.channels"))
    end

    it "lists the channels masked, with their monitors and latest delivery", :aggregate_failures do
      webhook = create(:notification_channel, project:, name: "Hooks", target: "https://hooks.example.com/T0/secret1234", creator: user)
      email = create(:notification_channel, :email, project:, name: "Mail", enabled: false)
      create(:monitor_channel, uptime_monitor: create(:uptime_monitor, project:), notification_channel: webhook)
      create(:notification_delivery, notification_channel: webhook, created_at: 2.hours.ago).deliver!
      failed = create(:notification_delivery, notification_channel: webhook, error: "unexpected_status", detail: "404")
      failed.give_up!
      create(:notification_delivery, notification_channel: email)
      create(:notification_channel, name: "Elsewhere")
      get monitoring_channels_path

      expect(response.body).to include("Hooks", "https://hooks.example.com/…1234", "1 monitor", I18n.t("monitoring.delivery_errors.unexpected_status"), "(404)")
      expect(response.body).to include("Mail", "ops@example.com", I18n.t("monitoring.channels.index.disabled"), monitoring_channel_test_path(webhook), monitoring_channel_secret_path(webhook))
      expect(response.body).not_to include("secret1234", "Elsewhere", webhook.signing_secret, monitoring_channel_secret_path(email))
    end

    it "hides the actions a member cannot use" do
      create(:membership, :owner, project:)
      membership.update!(role: "member")
      channel = create(:notification_channel, project:)
      get monitoring_channels_path

      expect(response.body).not_to include(monitoring_channel_test_path(channel))
    end
  end

  describe "create" do
    it "offers a choice of kinds, with email only when mail is configured", :aggregate_failures do
      get new_monitoring_channel_path

      expect(response.body).to include(new_monitoring_channel_path(kind: "webhook"), I18n.t("monitoring.channels.new.mail_disabled"))
      expect(response.body).not_to include(new_monitoring_channel_path(kind: "email"))

      enable_mail
      get new_monitoring_channel_path
      expect(response.body).to include(new_monitoring_channel_path(kind: "email"))
    end

    it "shows the form of a kind" do
      get new_monitoring_channel_path(kind: "webhook")

      expect(response.body).to include(I18n.t("monitoring.channels.form.targets.webhook"), 'name="notification_channel[kind]"')
    end

    it "creates a webhook and shows its signing secret once", :aggregate_failures do
      post monitoring_channels_path, params: { notification_channel: { kind: "webhook", name: "Hooks", target: "https://hooks.example.com/in", locale: "es", enabled: "1" } }
      channel = project.notification_channels.sole

      expect(response).to redirect_to(monitoring_channels_path)
      expect(channel).to have_attributes(name: "Hooks", locale: "es", creator: user, kind: "webhook")
      follow_redirect!
      expect(response.body).to include(channel.signing_secret, I18n.t("monitoring.channels.index.secret_hint"))
      get monitoring_channels_path
      expect(response.body).not_to include(channel.signing_secret)
    end

    it "creates Slack and Discord channels from their webhook URLs, refusing other hosts", :aggregate_failures do
      post monitoring_channels_path, params: { notification_channel: { kind: "slack", name: "Slack", target: "https://hooks.slack.com/services/T0/B0/xyz" } }
      post monitoring_channels_path, params: { notification_channel: { kind: "discord", name: "Discord", target: "https://discord.com/api/webhooks/1/xyz" } }

      expect(project.notification_channels.pluck(:kind)).to contain_exactly("slack", "discord")
      expect(project.notification_channels.map(&:signing_secret)).to all(be_nil)
      post monitoring_channels_path, params: { notification_channel: { kind: "slack", name: "Fake", target: "https://example.com/services/x" } }
      expect(response).to have_http_status(:unprocessable_content)
      get new_monitoring_channel_path
      expect(response.body).to include(new_monitoring_channel_path(kind: "slack"), new_monitoring_channel_path(kind: "discord"))
    end

    it "creates an email channel without a secret to show", :aggregate_failures do
      enable_mail
      post monitoring_channels_path, params: { notification_channel: { kind: "email", name: "Mail", target: "ops@example.com" } }

      expect(project.notification_channels.sole).to be_email
      follow_redirect!
      expect(response.body).not_to include(I18n.t("monitoring.channels.index.secret_hint"))
    end

    it "creates a channel for a monitor and connects it", :aggregate_failures do
      monitor = create(:uptime_monitor, project:, name: "API health")
      get new_monitoring_channel_path(monitor_id: monitor.id)
      expect(response.body).to include("API health</a>", monitoring_monitor_path(monitor), edit_monitoring_monitor_path(monitor), CGI.escapeHTML(new_monitoring_channel_path(kind: "slack", monitor_id: monitor.id)))

      get new_monitoring_channel_path(kind: "slack", monitor_id: monitor.id)
      expect(response.body).to include('name="monitor_id"', new_monitoring_channel_path(monitor_id: monitor.id))
      expect(response.body).to match(%r{href="#{monitoring_monitor_path(monitor)}">#{I18n.t("monitoring.form.cancel")}</a>})

      post monitoring_channels_path, params: { monitor_id: monitor.id, notification_channel: { kind: "slack", name: "Slack", target: "https://hooks.slack.com/services/T0/B0/xyz" } }
      expect(response).to redirect_to(monitoring_monitor_path(monitor))
      expect(flash[:notice]).to eq(I18n.t("monitoring.channels.create.connected", monitor: "API health"))
      expect(monitor.reload.notification_channels).to eq(project.notification_channels.to_a)
    end

    it "shows the secret of a webhook made for a monitor before going back to it", :aggregate_failures do
      monitor = create(:uptime_monitor, project:)
      post monitoring_channels_path, params: { monitor_id: monitor.id, notification_channel: { kind: "webhook", name: "Hooks", target: "https://hooks.example.com/in" } }

      expect(response).to redirect_to(monitoring_channels_path)
      expect(monitor.reload.notification_channels.sole.name).to eq("Hooks")
    end

    it "ignores a monitor the user may not edit or of another project", :aggregate_failures do
      create(:membership, :owner, project:)
      membership.update!(role: "member")
      theirs = create(:uptime_monitor, project:)
      post monitoring_channels_path, params: { monitor_id: theirs.id, notification_channel: { kind: "slack", name: "Slack", target: "https://hooks.slack.com/services/T0/B0/xyz" } }
      post monitoring_channels_path, params: { monitor_id: create(:uptime_monitor).id, notification_channel: { kind: "slack", name: "Other", target: "https://hooks.slack.com/services/T0/B0/abc" } }

      expect(response).to redirect_to(monitoring_channels_path)
      expect(theirs.notification_channels).to be_empty
      expect(project.notification_channels.count).to eq(2)
    end

    it "refuses email without mail and shows what is wrong", :aggregate_failures do
      post monitoring_channels_path, params: { notification_channel: { kind: "email", name: "Mail", target: "ops@example.com" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(project.notification_channels).to be_empty

      post monitoring_channels_path, params: { notification_channel: { kind: "webhook", name: "", target: "ftp://x" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(CGI.escapeHTML(I18n.t("activerecord.errors.models.notification_channel.attributes.target.invalid_url")))
    end
  end

  describe "update" do
    let(:channel) { create(:notification_channel, project:, creator: user, target: "https://hooks.example.com/in/abcd") }

    it "shows the URL masked and keeps it when left blank", :aggregate_failures do
      get edit_monitoring_channel_path(channel)

      expect(response.body).to include("https://hooks.example.com/…abcd", I18n.t("monitoring.channels.form.keep_url"))
      expect(response.body).not_to include("/in/abcd")

      patch monitoring_channel_path(channel), params: { notification_channel: { name: "Renamed", target: "", enabled: "0" } }
      expect(response).to redirect_to(monitoring_channels_path)
      expect(channel.reload).to have_attributes(name: "Renamed", target: "https://hooks.example.com/in/abcd", enabled: false)
    end

    it "shows what is wrong" do
      patch monitoring_channel_path(channel), params: { notification_channel: { name: "" } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "keeps a member away from a channel someone else created", :aggregate_failures do
      channel.update!(creator: create(:user))
      create(:membership, :owner, project:)
      membership.update!(role: "member")
      patch monitoring_channel_path(channel), params: { notification_channel: { name: "Mine" } }

      expect(channel.reload.name).not_to eq("Mine")
    end
  end

  it "deletes a channel" do
    channel = create(:notification_channel, project:)

    expect { delete monitoring_channel_path(channel) }.to change(NotificationChannel, :count).by(-1)
  end

  it "sends a test" do
    channel = create(:notification_channel, project:)

    expect { post monitoring_channel_test_path(channel) }.to have_enqueued_job(NotificationDeliveryJob)
  end

  it "regenerates a webhook's secret and shows it once, not for email", :aggregate_failures do
    channel = create(:notification_channel, project:)
    expect { post monitoring_channel_secret_path(channel) }.to(change { channel.reload.signing_secret })
    follow_redirect!
    expect(response.body).to include(channel.signing_secret)

    post monitoring_channel_secret_path(create(:notification_channel, :email, project:))
    expect(response).to have_http_status(:not_found)
  end

  it "does not reach a channel of another project" do
    get edit_monitoring_channel_path(create(:notification_channel))

    expect(response).to have_http_status(:not_found)
  end
end
