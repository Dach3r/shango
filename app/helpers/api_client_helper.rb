module ApiClientHelper
  TIMING_TONES = {
    "dns" => "bg-amber-400", "tcp" => "bg-sky-500", "tls" => "bg-indigo-500", "ttfb" => "bg-rose-500", "download" => "bg-emerald-500", "process" => "bg-zinc-500"
  }.freeze
  MIN_TIMING_WIDTH = 1.0
  BODY_LANGUAGES = { /json/ => "json", /xml/ => "xml", /html/ => "html", /javascript/ => "javascript" }.freeze

  # Select options for saving a draft: every collection and folder as "collection:<id>" / "folder:<id>".
  def destination_options(branches)
    branches.flat_map do |branch|
      collection = branch.collection
      [[collection.name, "collection:#{collection.id}"], *folder_destinations(branch, nil, collection.name)]
    end
  end

  def format_duration(milliseconds)
    return "-" if milliseconds.nil?

    milliseconds < 1000 ? "#{milliseconds} ms" : format("%.2f s", milliseconds / 1000.0)
  end

  # Millisecond figure for the timing breakdown: more precision for small values, seconds past 1000 ms.
  def format_timing(milliseconds)
    return format("%.2f s", milliseconds / 1000.0) if milliseconds >= 1000

    milliseconds >= 100 ? "#{milliseconds.round} ms" : format("%.2f ms", milliseconds)
  end

  # Waterfall rows for an execution's timings: phase, duration and the bar's left offset / width as percentages of the total.
  def timing_rows(execution)
    timings = execution.timings
    total = timings.values.sum
    return [] unless total.positive?

    offset = 0.0
    TIMING_TONES.filter_map do |phase, tone|
      milliseconds = timings[phase]
      next if milliseconds.nil? || (phase == "tls" && milliseconds.zero?)

      width = [milliseconds / total * 100, MIN_TIMING_WIDTH].max
      left = [offset / total * 100, 100 - width].min
      offset += milliseconds
      { phase:, tone:, milliseconds:, left:, width: }
    end
  end

  def format_size(bytes)
    number_to_human_size(bytes.to_i, precision: 3, significant: false)
  end

  def body_language(content_type)
    BODY_LANGUAGES.find { |pattern, _| content_type.to_s.match?(pattern) }&.last || "text"
  end

  # Response body formatted for reading; falls back to the raw text when it cannot be parsed.
  def pretty_body(execution)
    body = execution.response_body.to_s

    case body_language(execution.content_type)
    when "json" then JSON.pretty_generate(JSON.parse(body))
    when "xml" then pretty_xml(body)
    else body
    end
  rescue JSON::ParserError
    body
  end

  # Params table rows: the saved ones, or the query string of the URL when none were saved yet.
  def param_rows(api_request)
    return api_request.query_params if api_request.query_params.any?

    query = api_request.url.to_s.split("#").first.to_s.split("?", 2)[1].to_s
    query.split("&").compact_blank.map do |pair|
      key, value = pair.split("=", 2)
      { "key" => CGI.unescape(key.to_s), "value" => CGI.unescape(value.to_s), "enabled" => true, "description" => "" }
    end
  end

  def body_type_options
    ApiRequest::BODY_TYPES.map { |type| [t("workbench.body.types.#{type}"), type] }
  end

  def method_options
    ApiRequest::METHODS.map { |method| [method, method] }
  end

  private

  def folder_destinations(branch, parent, path)
    (parent ? branch.children_of(parent) : branch.root_folders).flat_map do |folder|
      label = "#{path} / #{folder.name}"
      [[label, "folder:#{folder.id}"], *folder_destinations(branch, folder, label)]
    end
  end

  def pretty_xml(body)
    document = Nokogiri::XML(body) { |config| config.noblanks }
    document.errors.empty? ? document.to_xml(indent: 2) : body
  end
end
