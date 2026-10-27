module Network
  module PortChecks
    # One line of the port table; `service` is the usual name of the port, not a detected one.
    Row = Data.define(:port, :service, :status, :ms)
  end
end
