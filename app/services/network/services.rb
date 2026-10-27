module Network
  # Well-known service names for the port check. A static table: probes never read banners, so the name only says
  # what the port is usually used for, not what is running on it.
  module Services
    NAMES = {
      21 => "ftp", 22 => "ssh", 23 => "telnet", 25 => "smtp", 53 => "dns", 80 => "http", 110 => "pop3", 143 => "imap",
      443 => "https", 465 => "smtps", 587 => "submission", 993 => "imaps", 995 => "pop3s", 1433 => "mssql", 3000 => "dev server",
      3306 => "mysql", 3389 => "rdp", 5432 => "postgresql", 5672 => "amqp", 6379 => "redis", 8080 => "http alt",
      8443 => "https alt", 9200 => "elasticsearch", 11_211 => "memcached", 27_017 => "mongodb"
    }.freeze

    def self.name(port)
      NAMES[port]
    end
  end
end
