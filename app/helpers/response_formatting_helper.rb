module ResponseFormattingHelper
  BODY_LANGUAGES = { /json/ => "json", /xml/ => "xml", /html/ => "html", /javascript/ => "javascript" }.freeze

  def format_duration(milliseconds)
    return "-" if milliseconds.nil?

    milliseconds < 1000 ? "#{milliseconds} ms" : format("%.2f s", milliseconds / 1000.0)
  end

  # Millisecond figure for the timing breakdown: more precision for small values, seconds past 1000 ms.
  def format_timing(milliseconds)
    return format("%.2f s", milliseconds / 1000.0) if milliseconds >= 1000

    milliseconds >= 100 ? "#{milliseconds.round} ms" : format("%.2f ms", milliseconds)
  end

  # The cookies a response set, parsed from the stored Set-Cookie lines.
  def response_cookies(execution)
    execution.set_cookies.filter_map { |line| ApiClient::SetCookie.parse(line) }
  end

  def format_size(bytes)
    number_to_human_size(bytes.to_i, precision: 3, significant: false)
  end

  def body_language(content_type)
    BODY_LANGUAGES.find { |pattern, _| content_type.to_s.match?(pattern) }&.last || "text"
  end

  # Language of the payload that was sent: its Content-Type header, else sniffed from the body.
  def payload_language(execution)
    _, content_type = execution.request_headers.find { |name, _| name.to_s.casecmp?("content-type") }
    language = body_language(content_type)
    return language unless language == "text"

    JSON.parse(execution.request_body.to_s)
    "json"
  rescue JSON::ParserError
    execution.request_body.to_s.lstrip.start_with?("<") ? "xml" : "text"
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

  private

  def pretty_xml(body)
    document = Nokogiri::XML(body) { |config| config.noblanks }
    document.errors.empty? ? document.to_xml(indent: 2) : body
  end
end
