module Workbench
  # Strong parameters for the request editor form.
  module RequestParameters
    extend ActiveSupport::Concern

    ROW_FIELDS = %i[key value enabled description type attachment_id upload_token].freeze
    SCALAR_FIELDS = %i[name http_method url description folder_id body_type body graphql_variables auth_type].freeze

    private

    def request_attributes
      params.fetch(:api_request, {}).permit(
        *SCALAR_FIELDS,
        auth_config: {}, settings: %i[timeout follow_redirects max_redirects verify_ssl use_cookie_jar],
        query_params: [ROW_FIELDS], headers: [ROW_FIELDS], body_form: [ROW_FIELDS]
      )
    end

    # Files posted for multipart rows, keyed by the row's upload token.
    def request_uploads
      uploads = params.dig(:api_request, :body_uploads)
      return {} unless uploads.respond_to?(:each_pair)

      uploads.each_pair.select { |_token, file| uploaded_file?(file) }.to_h
    end

    def binary_upload
      file = params.dig(:api_request, :binary_upload)
      file if uploaded_file?(file)
    end

    def uploaded_file?(value)
      value.respond_to?(:original_filename) && value.respond_to?(:tempfile)
    end
  end
end
