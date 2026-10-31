module NetworkHelper
  BAR_FORM_CLASSES = "flex h-14 items-stretch [&>*:not(label)]:relative [&>*:not(label)~*:not(label)]:-ml-px [&>*:not(label):focus-within]:z-10 [&>input]:border-t-0 [&_[data-select-target=trigger]]:h-full [&_[data-select-target=trigger]]:border-t-0 [&>label:first-child+*]:border-l-0 [&_[data-select-target=trigger]:focus]:border-line! [&_[data-select-target=trigger]:focus]:ring-0! [&>:is(button,a)]:border-b [&>:is(button,a)]:border-r [&>:is(button,a)]:border-line".freeze

  MONITOR_KINDS = { "ping" => "tcp", "ports" => "tcp", "tls" => "ssl", "dns" => "domain", "lookup" => "domain" }.freeze

  # The monitor form that watches what a saved run checked, or nil when its tool has no monitor of that kind.
  def network_monitor_path(check)
    kind = MONITOR_KINDS[check.kind]
    host = (check.input["host"] || check.input["domain"]).to_s
    return if kind.nil? || host.blank? || (kind == "domain" && Monitoring::Probes::Ssl.ip?(host))

    new_monitoring_monitor_path(kind:, target: host, port_number: (network_monitor_port(check) if kind != "domain"))
  end

  def network_monitor_port(check)
    input = check.input
    case check.kind
    when "ping" then input["port"].presence || Network::Pings::Run::DEFAULT_PORT
    when "ports" then input["ports"].to_s[/\A\d+\z/] || Network::Pings::Run::DEFAULT_PORT
    else input["port"].presence || Network::TlsChecks::Run::DEFAULT_PORTS.fetch(input.fetch("protocol", "tls"), 443)
    end
  end

  # The prefilled inputs of a tool opened from a monitor (`?host=&port=`), or the inputs of the saved run on display.
  def network_input(check)
    check&.input || @prefill || {}
  end

  # Form bar of a tool. Always submittable: on a saved run, submitting records a new run.
  def network_bar(scope:, url:, &)
    form_with(scope:, url:, class: BAR_FORM_CLASSES, &)
  end

  # Options of the port presets: the value is what the ports field receives; `custom` leaves the field as typed and is labelled with the typed list.
  def port_preset_options(custom: nil)
    presets = Network::PortChecks::PortSpec::PRESETS.map { |name, ports| [t("network.ports.presets.#{name}", ports: ports.join(", ")), ports.join(", ")] }
    [[t("network.ports.presets.common"), "common"], *presets, [custom.presence || t("network.ports.presets.custom"), "custom"]]
  end

  # The preset value matching what is typed in the ports field, or `custom`.
  def port_preset_for(ports)
    typed = ports.to_s.strip
    port_preset_options.map(&:last).find { |value| value == typed && value != "custom" } || "custom"
  end

  # The state of one part of an email check (spf, dkim, dmarc, mx) for its tile, from the findings that belong to it.
  def email_section_status(data, section)
    findings = data[:findings].select { |finding| finding[:key].start_with?("#{section}.") }
    return :missing if findings.any? { |finding| finding[:key].end_with?(".missing") }

    tones = findings.pluck(:tone)
    return :broken if tones.include?("bad")

    tones.include?("warn") ? :attention : :healthy
  end

  # The state of the days left before a domain expires.
  def lookup_expiry_status(days_left)
    return :expired if days_left.negative?

    days_left <= Network::Lookups::Domain::EXPIRING_DAYS ? :expiring : :valid
  end
end
