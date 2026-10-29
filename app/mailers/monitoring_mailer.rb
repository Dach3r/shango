# Alerts of a monitor to an email channel, in the channel's language.
class MonitoringMailer < ApplicationMailer
  def alert
    @message = Monitoring::Notifications::Message.new(params[:delivery])

    I18n.with_locale(@message.locale) do
      mail to: @message.channel.addresses, subject: @message.subject
    end
  end
end
