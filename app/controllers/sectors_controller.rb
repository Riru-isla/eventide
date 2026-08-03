class SectorsController < ApplicationController
  def show
    @galaxy = Galaxy.find(params[:galaxy_id])
    @sector = @galaxy.sectors.find(params[:id])
    @empire = current_empire
    @fleets = @sector.stationed_fleets.where(empire: @empire)
  end
end
