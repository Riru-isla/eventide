class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :authenticate_user!
  before_action :set_current_empire

  helper_method :current_player, :current_empire

  private

  def current_player
    @current_player ||= current_user&.players&.find_by(galaxy_id: Galaxy.first&.id)
  end

  def current_empire
    @current_empire ||= Empire.find_by(id: session[:empire_id]) if session[:empire_id]
    @current_empire ||= current_player&.empires&.first
  end

  def set_current_empire
    return unless current_user

    session[:empire_id] ||= current_empire&.id
  end

  def after_sign_in_path_for(_resource)
    galaxy_path(Galaxy.first)
  end

  def after_sign_out_path_for(_resource)
    new_user_session_path
  end
end
