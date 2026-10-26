module ApiClient
  module Imports
    # Identifies which app produced a parsed export (Result#record is the format symbol).
    class Detector
      include Serviceable

      def initialize(data:)
        @data = data
      end

      private

      def perform
        format = detect
        format ? Result.success(format) : Result.failure(error: I18n.t("workbench.imports.errors.unknown_format"))
      end

      def detect
        return unless @data.is_a?(Hash)

        if @data["openapi"] || @data["swagger"] then :openapi
        elsif @data["info"].is_a?(Hash) && @data["item"].is_a?(Array) then :postman
        elsif @data["values"].is_a?(Array) && !@data.key?("info") then :postman_environment
        elsif @data["_type"] == "export" || @data["type"].to_s.start_with?("collection.insomnia.rest") then :insomnia
        elsif @data["items"].is_a?(Array) && @data["name"] then :bruno
        end
      end
    end
  end
end
