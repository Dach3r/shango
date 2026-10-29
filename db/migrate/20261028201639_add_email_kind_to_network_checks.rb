class AddEmailKindToNetworkChecks < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :network_checks, "kind IN ('dns', 'ports', 'ping', 'subnet', 'tls')", name: "network_checks_kind_check"
    add_check_constraint :network_checks, "kind IN ('dns', 'ports', 'ping', 'subnet', 'tls', 'email')", name: "network_checks_kind_check"
  end
end
