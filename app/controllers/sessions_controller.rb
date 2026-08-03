class SessionsController < ApplicationController
  skip_before_action :require_login, only: %i[new create]

  def new
    redirect_to galaxy_path(Galaxy.first) if current_empire
    @galaxy = Galaxy.first
  end

  def create
    galaxy = Galaxy.find(params[:galaxy_id])
    empire = galaxy.empires.find_by(id: params[:empire_id])

    if empire&.authenticate(params[:password])
      session[:empire_id] = empire.id
      redirect_to galaxy_path(galaxy), notice: "Welcome, #{empire.player.name}."
    else
      flash.now[:alert] = "Invalid empire or password."
      @galaxy = galaxy
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    session.delete(:empire_id)
    redirect_to root_path, notice: "Logged out."
  end
end
