module ApiClientHelper
  BODY_LANGUAGES = { /json/ => "json", /xml/ => "xml", /html/ => "html", /javascript/ => "javascript" }.freeze

  def format_duration(milliseconds)
    return "-" if milliseconds.nil?

    milliseconds < 1000 ? "#{milliseconds} ms" : format("%.2f s", milliseconds / 1000.0)
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

  def pretty_xml(body)
    document = Nokogiri::XML(body) { |config| config.noblanks }
    document.errors.empty? ? document.to_xml(indent: 2) : body
  end
end
