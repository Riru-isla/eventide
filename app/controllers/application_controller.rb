class ApplicationController < ActionController::Base
  # No browser gate: the game is hosted on a laptop for whoever is around, and the
  # :modern check returns 406 to browsers that would otherwise play fine.

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
    planet_path
  end

  def after_sign_out_path_for(_resource)
    new_user_session_path
  end
end
