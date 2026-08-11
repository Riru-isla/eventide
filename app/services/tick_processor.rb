class TickProcessor
  def initialize(galaxy)
    @galaxy = galaxy
  end

  def process
    ActiveRecord::Base.transaction do
      # Builds and research finish before income is collected, so anything completing
      # this tick contributes to it.
      complete_builds
      complete_research
      collect_resources
      resolve_fleet_arrivals
      @galaxy.increment!(:current_tick)
    end

    broadcast_tick
  end

  private

  # Tells every connected client to re-render. Without this a queue keeps claiming
  # "2 ticks left" long after those ticks have passed, because nothing on the page
  # ever changes until the player reloads.
  #
  # Deliberately sent after the transaction commits, or a client could refresh fast
  # enough to read the previous tick's state. A refresh broadcast carries no data —
  # it only asks each client to re-fetch the page it is already on, and that fetch is
  # authenticated as usual.
  def broadcast_tick
    Turbo::StreamsChannel.broadcast_refresh_to(@galaxy)
  end

  def complete_builds
    Planet.where(empire_id: @galaxy.empires.select(:id)).includes(:build_orders, :structures, :sector)
          .find_each do |planet|
      planet.queue.advance!
      planet.shipyard.advance!
    end
  end

  def complete_research
    @galaxy.empires.includes(:technologies, :research_orders).find_each { |empire| empire.research.advance! }
  end

  # Income comes from two places: the empire's planet, where structure levels and
  # the energy balance decide the yield, and any other sector it holds, which still
  # contributes its flat rate. Energy is not collected — it is a balance on the
  # planet, not a stored resource.
  def collect_resources
    @galaxy.empires.includes(planet: [ :structures, :sector ]).find_each do |empire|
      income = planet_income(empire)
      add_sector_income(empire, income)

      empire.update!(
        metal: store(empire, :metal, income[:metal]),
        crystal: store(empire, :crystal, income[:crystal]),
        crew: store(empire, :crew, income[:crew])
      )
    end
  end

  # Income stops at the empire's storage capacity. A stockpile already over capacity
  # is left alone rather than confiscated — running out of room should stall growth,
  # not destroy what a player has banked.
  def store(empire, resource, income)
    current = empire.public_send(resource)
    capacity = empire.storage_capacity(resource)
    return current if current >= capacity

    [ current + income, capacity ].min
  end

  def planet_income(empire)
    return { metal: 0, crystal: 0, crew: 0 } unless empire.planet

    economy = empire.planet.economy

    { metal: economy.output(:metal), crystal: economy.output(:crystal), crew: economy.crew_production }
  end

  def add_sector_income(empire, income)
    planet_sector_id = empire.planet&.sector_id

    empire.sectors.where.not(id: planet_sector_id).find_each do |sector|
      income[:metal] += (sector.metal_rate * empire.resource_bonus(:metal)).to_i
      income[:crystal] += (sector.crystal_rate * empire.resource_bonus(:crystal)).to_i
    end
  end

  def resolve_fleet_arrivals
    due = @galaxy.fleets.under_way.where("arrival_tick <= ?", @galaxy.current_tick)

    due.find_each do |fleet|
      if fleet.status == "returning"
        arrive_home(fleet)
      elsif fleet.target_sector.nil?
        next
      elsif fleet.transport?
        deliver_shipment(fleet)
      else
        resolve_combat(fleet)
      end
    end
  end

  # A transport hands its cargo to whoever holds the destination, then turns around.
  # Delivering to an unowned sector is a wasted trip rather than a loss: the hold stays
  # full and comes home.
  def deliver_shipment(fleet)
    recipient = fleet.target_sector.empire
    Shipment.new(fleet).deliver!(recipient) if recipient

    fleet.turn_for_home!(@galaxy.current_tick, return_ticks(fleet))
  end

  def arrive_home(fleet)
    # Anything undelivered — no recipient, or their stores were full — goes back to the
    # sender rather than vanishing.
    Shipment.new(fleet).unload_home! if fleet.carrying?
    fleet.join_garrison!
  end

  def return_ticks(fleet)
    fleet.travel_ticks_between(fleet.target_sector, fleet.origin_sector)
  end

  # A captured sector is stripped of what the fleet can carry. Transports exist for
  # this: without cargo space a victory takes the ground but none of the spoils.
  def plunder!(fleet, target)
    capacity = fleet.cargo_capacity
    return if capacity.zero?

    haul = [ (target.metal_rate.to_i + target.crystal_rate.to_i) * 10, capacity ].min
    empire = fleet.empire

    empire.update!(
      metal: [ empire.metal + (haul / 2), empire.storage_capacity(:metal) ].min,
      crystal: [ empire.crystal + (haul / 2), empire.storage_capacity(:crystal) ].min
    )
  end

  def resolve_combat(fleet)
    target = fleet.target_sector

    if target.npc_faction
      defender_power = target.total_defence
      attacker_power = fleet.power

      if attacker_power >= defender_power
        plunder!(fleet, target)
        target.update!(
          npc_faction: nil,
          empire: fleet.empire,
          kind: "resource",
          defense_strength: [ attacker_power / 2, 1 ].max
        )
        fleet.join_garrison!(target)
      elsif !fleet.retreat!
        # Nothing survived the failed attack.
        fleet.destroy!
      end
    else
      fleet.join_garrison!(target)
    end
  end
end
