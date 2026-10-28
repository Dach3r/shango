module Projects
  class ThemesController < AuthenticatedController
    def edit
      @membership = current_membership
      authorize @membership, :update?
    end

    def update
      @membership = current_membership
      authorize @membership
      return redirect_to(edit_theme_path, status: :see_other) if @membership.update(theme_params)

      render :edit, status: :unprocessable_entity
    end

    private

    def theme_params
      params.expect(membership: %i[color_scheme theme])
    end
  end
end
