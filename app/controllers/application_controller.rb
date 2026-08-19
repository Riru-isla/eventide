class ApplicationController < ActionController::Base
  # No browser gate: the game is hosted on a laptop for whoever is around, and the
  # :modern check returns 406 to browsers that would otherwise play fine.

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :authenticate_user!
  before_action :require_empire

  helper_method :current_empire, :current_galaxy, :admin?

  private

  # Which empire this session is playing. A user holds at most one empire per galaxy, so
  # the session is what decides which galaxy they are looking at; joining one, or opening
  # its galaxy screen, switches it.
  def current_empire
    @current_empire ||= user_empires.find_by(id: session[:empire_id]) || user_empires.last
  end

  def current_galaxy
    current_empire&.galaxy
  end

  # Not a role system: one flag, so the generate and inspect controls stay out of the way
  # of people who are only here to play.
  def admin?
    current_user&.admin?
  end

  def user_empires
    return Empire.none unless current_user

    Empire.where(player_id: current_user.players.select(:id)).order(:created_at)
  end

  # Every game screen is a view onto one empire, so without one there is nothing to draw.
  # The lobby is where you pick a galaxy or make one.
  def require_empire
    return unless current_user
    return if current_empire

    redirect_to galaxies_path, notice: "Choose a galaxy to command in."
  end

  def require_admin
    redirect_to galaxies_path, alert: "That is an administrator control." unless admin?
  end

  def after_sign_in_path_for(_resource)
    current_empire ? planet_path : galaxies_path
  end

  def after_sign_out_path_for(_resource)
    new_user_session_path
  end
end
