class AuthenticatedController < ApplicationController
  include ProjectContext
  include Authorization

  layout -> { turbo_frame_request? ? "turbo_rails/frame" : "app" }

  before_action :authenticate_user!
  before_action :require_project
end
