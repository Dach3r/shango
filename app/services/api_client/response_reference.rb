module ApiClient
  # Reads a `response.<attr>.<request_id>[.<filter>]` reference: a value taken from the latest response of another request
  # in the same collection. Result#record is the value as a string; failures carry the reason in `error`
  # (:invalid, :unknown_request, :no_response, :no_match).
  class ResponseReference
    include Serviceable

    ATTRIBUTES = %w[body raw header url].freeze
    FILTERED = %w[body header].freeze
    PATTERN = /\Aresponse\.(?<attribute>#{ATTRIBUTES.join("|")})\.(?<request_id>\h{8}-\h{4}-\h{4}-\h{4}-\h{12})(?:\.(?<filter>.+))?\z/

    Parsed = Struct.new(:attribute, :request_id, :filter, keyword_init: true)

    def self.parse(name)
      match = PATTERN.match(name.to_s)
      return unless match

      parsed = Parsed.new(attribute: match[:attribute], request_id: match[:request_id].downcase, filter: match[:filter])
      parsed unless FILTERED.include?(parsed.attribute) && parsed.filter.blank?
    end

    def self.reference?(name)
      name.to_s.start_with?("response.")
    end

    def initialize(api_request:, user:, name:)
      @api_request = api_request
      @user = user
      @name = name
    end

    private

    def perform
      reference = self.class.parse(@name)
      return Result.failure(error: :invalid) unless reference

      target = sibling(reference.request_id)
      return Result.failure(error: :unknown_request) unless target

      execution = RequestExecution.latest_for(target, @user)
      return Result.failure(target, error: :no_response) if execution.nil? || execution.error?

      extract(target, execution, reference)
    end

    def sibling(request_id)
      return if @api_request.collection_id.blank?

      ApiRequest.find_by(id: request_id, project_id: @api_request.project_id, collection_id: @api_request.collection_id)
    end

    def extract(target, execution, reference)
      value = case reference.attribute
      when "url" then execution.url
      when "raw" then execution.response_body
      when "header" then header(execution, reference.filter)
      else json_value(execution.response_body, reference.filter)
      end

      value.nil? ? Result.failure(target, error: :no_match) : Result.success(value.to_s, request: target)
    end

    def header(execution, name)
      Array(execution.response_headers).find { |key, _| key.to_s.casecmp?(name) }&.last
    end

    def json_value(body, filter)
      return if body.blank?

      matches = JsonPath.new(filter).on(JSON.parse(body))
      value = matches.one? ? matches.first : matches.presence
      value.is_a?(String) || value.nil? ? value : value.to_json
    rescue JSON::ParserError, ArgumentError
      nil
    end
  end
end
