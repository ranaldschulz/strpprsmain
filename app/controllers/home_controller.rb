class HomeController < ApplicationController

  def index
    @q = Service.open.active.search(params[:q])
    @top_services = Service.top_rated.limit(4).includes(:category, :primary_image, performers: :profile)
  end

  def work_with_us
  end
end
