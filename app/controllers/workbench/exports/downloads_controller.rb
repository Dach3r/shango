module Workbench
  module Exports
    # The finished file of an export, for the member who asked for it.
    class DownloadsController < Workbench::BaseController
      def show
        export = current_project.collection_exports.where(user: current_user).find(params[:export_id])
        authorize export, :download?
        return head :gone unless export.downloadable?

        send_data export.file_content, filename: export.filename, type: export.content_type, disposition: "attachment"
      end
    end
  end
end
