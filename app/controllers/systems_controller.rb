class SystemsController < ApplicationController
  def show
    @galaxy = Galaxy.find(params[:galaxy_id])
    @system = @galaxy.systems.find(params[:id])
    @empire = current_empire
    @fleets = @system.stationed_fleets.where(empire: @empire)
  end
end
