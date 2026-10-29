# Every minute: enqueues the checks of the monitors that are due (see Monitoring::Monitors::Dispatch).
class MonitoringDispatchJob < ApplicationJob
  queue_as :monitoring

  def perform
    Monitoring::Monitors::Dispatch.call
  end
end
