class ShipyardController < ApplicationController
  def create
    @galaxy = Galaxy.find(params[:galaxy_id])
    @sector = current_empire.sectors.find(params[:sector_id])

    ship_type = ShipType.find(params[:ship_type_id])
    quantity = params[:quantity].to_i

    if quantity <= 0
      redirect_to galaxy_sector_path(@galaxy, @sector), alert: "Quantity must be greater than zero."
      return
    end

    # Energy is a planet-side balance rather than a stored resource, so hulls are
    # paid for in metal and crystal only.
    cost = {
      metal: ship_type.metal_cost * quantity,
      crystal: ship_type.crystal_cost * quantity
    }

    if current_empire.metal < cost[:metal] || current_empire.crystal < cost[:crystal]
      redirect_to galaxy_sector_path(@galaxy, @sector), alert: "Not enough resources."
      return
    end

    new_ships = { ship_type.name => quantity }

    ActiveRecord::Base.transaction do
      current_empire.update!(
        metal: current_empire.metal - cost[:metal],
        crystal: current_empire.crystal - cost[:crystal]
      )

      fleet = @galaxy.fleets.find_by(empire: current_empire, origin_sector: @sector, status: "orbiting")

      if fleet
        fleet.ships[ship_type.name] ||= 0
        fleet.ships[ship_type.name] += quantity
        fleet.save!
      else
        @galaxy.fleets.create!(
          empire: current_empire,
          origin_sector: @sector,
          status: "orbiting",
          ships: new_ships
        )
      end
    end

    redirect_to galaxy_sector_path(@galaxy, @sector), notice: "Built #{quantity} #{ship_type.name}."
  end
end
