module NetworkHelper
  BAR_FORM_CLASSES = "flex h-14 items-stretch [&>*:not(label)]:relative [&>*:not(label)~*:not(label)]:-ml-px [&>*:not(label):focus-within]:z-10 [&>input]:border-t-0 [&_[data-select-target=trigger]]:h-full [&_[data-select-target=trigger]]:border-t-0 [&>label:first-child+*]:border-l-0".freeze

  # Form bar of a tool. A saved run (`readonly: true`) renders the same fields without a form, so it cannot be submitted.
  def network_bar(scope:, url:, readonly:, &)
    return form_with(scope:, url:, class: BAR_FORM_CLASSES, &) unless readonly

    tag.div(class: BAR_FORM_CLASSES) { fields(scope, &) }
  end
end
