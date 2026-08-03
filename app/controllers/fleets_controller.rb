class FleetsController < ApplicationController
  def create
    @galaxy = Galaxy.find(params[:galaxy_id])
    empire = @galaxy.empires.find(params[:fleet][:empire_id])
    origin = @galaxy.sectors.find(params[:fleet][:origin_sector_id])
    target = @galaxy.sectors.find(params[:fleet][:target_sector_id])

    travel_ticks = [ origin.distance_to(target.x, target.y).ceil, 1 ].max

    @galaxy.fleets.create!(
      empire: empire,
      origin_sector: origin,
      target_sector: target,
      arrival_tick: @galaxy.current_tick + travel_ticks,
      status: "moving",
      ships: fleet_ships_param
    )

    redirect_to galaxy_path(@galaxy), notice: "Fleet dispatched to #{target.coordinate}."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
    redirect_to galaxy_path(@galaxy), alert: "Could not dispatch fleet: #{e.message}"
  end

  private

  def fleet_ships_param
    ships = params[:fleet][:ships].to_unsafe_h
    ships.transform_values(&:to_i).reject { |_, count| count <= 0 }
  end
end
