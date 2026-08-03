class TickProcessor
  def initialize(galaxy)
    @galaxy = galaxy
  end

  def process
    ActiveRecord::Base.transaction do
      collect_resources
      resolve_fleet_arrivals
      @galaxy.increment!(:current_tick)
    end
  end

  private

  def collect_resources
    @galaxy.empires.find_each do |empire|
      income = { metal: 0, crystal: 0, energy: 0 }

      empire.sectors.find_each do |sector|
        income[:metal] += (sector.metal_rate * empire.resource_bonus(:metal)).to_i
        income[:crystal] += (sector.crystal_rate * empire.resource_bonus(:crystal)).to_i
        income[:energy] += (sector.energy_rate * empire.resource_bonus(:energy)).to_i
      end

      empire.update!(
        metal: empire.metal + income[:metal],
        crystal: empire.crystal + income[:crystal],
        energy: empire.energy + income[:energy]
      )
    end
  end

  def resolve_fleet_arrivals
    @galaxy.fleets.moving.where("arrival_tick <= ?", @galaxy.current_tick).find_each do |fleet|
      next unless fleet.target_sector

      resolve_combat(fleet)
    end
  end

  def resolve_combat(fleet)
    target = fleet.target_sector

    if target.npc_faction
      defender_power = target.defense_strength
      attacker_power = fleet.power

      if attacker_power >= defender_power
        target.update!(
          npc_faction: nil,
          empire: fleet.empire,
          kind: "resource",
          defense_strength: [ attacker_power / 2, 1 ].max
        )
        fleet.update!(
          origin_sector: target,
          target_sector: nil,
          status: "orbiting",
          arrival_tick: nil
        )
      else
        # Attacker loses; simplistic: destroy fleet
        fleet.destroy!
      end
    else
      fleet.update!(
        origin_sector: target,
        target_sector: nil,
        status: "orbiting",
        arrival_tick: nil
      )
    end
  end
end
