module System
  class UsersController < System::BaseController

    def show
      @profile = @user.profile if @user.dancer?
    end

    def edit
      if @user.dancer?
        @user.build_profile if @user.profile.nil?
        @user.build_location if @user.location.nil?
      end
    end

    def update
      if @user.update(user_params)
        redirect_to (@user.dancer? && !@user.services.any? ? new_system_service_path : :back), notice: t('.notice')
      else
        render :edit
      end
    end

    def become_dancer
      @user.dancer!
      redirect_to edit_system_user_path(current_user)
    end

    def media
    end

    private

    def user_params
      params.require(:user).permit(
        :first_name, :last_name, :email, :gender, :description, :avatar, :avatar_cache,
        profile_attributes: [:id, :perform_name, :height, :weight, :bust, :ethnicity, :birth_date, :phone_number],
        location_attributes: [:id, :address, :country, :postal_code, :lat, :lng],
        service_images_attributes: [:id, :profile]
      )
    end
  end
end