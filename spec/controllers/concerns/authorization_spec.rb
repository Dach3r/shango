require "rails_helper"

RSpec.describe Authorization do
  controller(AuthenticatedController) do
    def index
      raise Pundit::NotAuthorizedError
    end
  end

  let(:user) { create(:user) }
  let!(:membership) { create(:membership, :owner, user:) }

  before do
    user.update!(current_membership: membership)
    sign_in user
  end

  it "authorizes as the current membership" do
    get :index

    expect(controller.send(:pundit_user)).to eq(membership)
  end

  it "sends browser navigations back with a toast", :aggregate_failures do
    request.headers["Accept"] = "text/html"
    get :index

    expect(response).to redirect_to(workbench_root_path)
    expect(flash[:alert]).to eq(I18n.t("authorization.forbidden"))
  end

  it "answers background requests with a bare 403" do
    request.headers["Accept"] = "*/*"
    get :index

    expect(response).to have_http_status(:forbidden)
  end
end
