class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :require_login

  helper_method :current_player, :current_empire

  private

  def current_player
    @current_player ||= Player.find_by(id: session[:player_id]) if session[:player_id]
  end

  def current_empire
    @current_empire ||= Empire.find_by(id: session[:empire_id]) if session[:empire_id]
  end

  def require_login
    return if current_player

    redirect_to new_session_path, alert: "Please log in to continue."
  end
end
