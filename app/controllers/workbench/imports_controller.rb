module Workbench
  class ImportsController < BaseController
    MAX_WARNINGS_SHOWN = 2

    throttle :imports, by: -> { current_user.id }, only: :create

    def new
      authorize current_project, :import?
    end

    def create
      authorize current_project, :import?
      result = ApiClient::Imports::Import.call(project: current_project, creator: current_user, content: submitted_content)
      return redirect_to(workbench_root_path, notice: summary(result.data), status: :see_other) if result.success?

      @error = result.error
      render_form_errors
    end

    private

    def submitted_content
      file = params[:file]
      return file.tempfile.read(ApiClient::Imports::Import::MAX_BYTES + 1).to_s if file.respond_to?(:tempfile)

      params[:content].to_s
    end

    def summary(data)
      counts = %i[collections folders requests environments].select { |key| data[key].positive? }.map { |key| t(".counts.#{key}", count: data[key]) }
      message = t(".imported", counts: counts.to_sentence)
      return message if data[:warnings].empty?

      shown = data[:warnings].first(MAX_WARNINGS_SHOWN).join(" ")
      "#{message} #{t(".warnings", count: data[:warnings].size, details: shown)}".truncate(600)
    end
  end
end
