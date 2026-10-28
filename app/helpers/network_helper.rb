module NetworkHelper
  BAR_FORM_CLASSES = "flex h-14 items-stretch [&>*:not(label)]:relative [&>*:not(label)~*:not(label)]:-ml-px [&>*:not(label):focus-within]:z-10 [&>input]:border-t-0 [&_[data-select-target=trigger]]:h-full [&_[data-select-target=trigger]]:border-t-0 [&>label:first-child+*]:border-l-0 [&_[data-select-target=trigger]:focus]:border-line! [&_[data-select-target=trigger]:focus]:ring-0! [&>:is(button,a)]:border-b [&>:is(button,a)]:border-r [&>:is(button,a)]:border-line".freeze

  # Form bar of a tool. A saved run (`readonly: true`) renders the same fields without a form, so it cannot be submitted.
  def network_bar(scope:, url:, readonly:, &)
    return form_with(scope:, url:, class: BAR_FORM_CLASSES, &) unless readonly

    tag.div(class: BAR_FORM_CLASSES) { fields(scope, &) }
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
end
