module ApplicationCable
  # Only signed-in users open a socket; the stream names they subscribe to are signed by the page that rendered them.
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = env["warden"].user(:user) || reject_unauthorized_connection
    end
  end
end
