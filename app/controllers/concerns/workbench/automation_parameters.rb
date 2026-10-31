module Workbench
  # Strong parameters for the assertion and extractor rows of a request, folder or collection form.
  module AutomationParameters
    extend ActiveSupport::Concern

    ASSERTION_FIELDS = %i[id enabled source target operator expected].freeze
    EXTRACTOR_FIELDS = %i[id enabled source target variable secret].freeze

    private

    SCRIPT_FIELDS = %i[pre_request_script post_response_script].freeze

    def automation_permits
      { assertions: [ASSERTION_FIELDS], extractors: [EXTRACTOR_FIELDS] }
    end
  end
end
