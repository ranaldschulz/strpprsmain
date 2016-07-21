class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_filter :load_pages

  rescue_from CanCan::AccessDenied do |exception|
    redirect_to main_app.root_url, alert: exception.message
  end

  def after_sign_in_path_for(resource)
    if resource.dancer? && resource.profile.nil?
      edit_system_user_path(resource)
    elsif request.env['omniauth.origin']
      request.env['omniauth.origin']
    elsif stored_location_for(resource)
      stored_location_for(resource)
    elsif request.referer == new_user_session_url
      super
    else
      root_path
    end
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name, :role, :accept_terms])
  end

  private

  def load_pages
    @pages = Page.order(:id).active.general
  end
end
