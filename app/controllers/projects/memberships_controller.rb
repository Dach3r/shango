module Projects
  class MembershipsController < AuthenticatedController
    def edit
      @membership = current_membership
    end

    def update
      @membership = current_membership
      return redirect_to(edit_membership_path, notice: t(".updated"), status: :see_other) if @membership.update(membership_params)

      render :edit, status: :unprocessable_entity
    end

    private

    def membership_params
      params.expect(membership: %i[folder_toggle request_open collapse_nested_folders])
    end
  end
end
