class SessionsController < ApplicationController
  skip_before_action :require_login, only: %i[new create]

  def new
    redirect_to galaxy_path(Galaxy.first) if current_player
    @galaxy = Galaxy.first
  end

  def create
    player = Player.find_by(username: params[:username])

    if player&.authenticate(params[:password])
      session[:player_id] = player.id
      session[:empire_id] = player.empires.first&.id
      redirect_to galaxy_path(Galaxy.first), notice: "Welcome back, #{player.name}."
    else
      flash.now[:alert] = "Invalid username or password."
      @galaxy = Galaxy.first
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    session.delete(:player_id)
    session.delete(:empire_id)
    redirect_to new_session_path, notice: "Logged out."
  end
end
