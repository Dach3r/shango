module RequestFormHelper
  # Names of the path to an open request: its collection (or "Draft") and the folders down to it.
  def request_breadcrumb(api_request, branches)
    return [t("workbench.requests.draft")] if api_request.draft?

    branch = branches.find { |item| item.collection.id == api_request.collection_id }
    [branch.collection.name, *branch.folder_path(api_request.folder_id).map(&:name)]
  end

  # URL split into the pieces the request tab styles separately.
  def url_parts(url)
    url.to_s.match(%r{\A(?<scheme>[a-z][a-z0-9+.-]*://)?(?<host>[^/?#]*)(?<path>[^?#]*)(?<query>\?[^#]*)?(?<fragment>#.*)?\z}im).named_captures.symbolize_keys
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

  # Data attributes that turn the plain inputs inside an element into `{{variable}}` autocompletes.
  def variable_autocomplete_data(controller: nil)
    labels = I18n.t("components.code_editor").transform_keys { |key| key.to_s.camelize(:lower) }
    {
      controller: [controller, "variable-autocomplete"].compact.join(" "),
      variable_autocomplete_variables_value: editor_variables.to_json,
      variable_autocomplete_responses_value: editor_responses.to_json,
      variable_autocomplete_responses_url_value: editor_responses_url,
      variable_autocomplete_labels_value: labels.to_json
    }
  end

  def method_options
    ApiRequest::METHODS.map { |method| [method, method] }
  end
end
