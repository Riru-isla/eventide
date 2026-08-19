# Creates everything a new commander needs: a player, an empire, a claimed home
# system, and a starting fleet.
#
# Galaxy seeding and player signup both go through here so that a seeded demo
# empire and one created from the signup form are identical.
class EmpireFounder
  class NoHomeSystemAvailable < StandardError; end

  STARTING_RESOURCES = { metal: 500, crystal: 500, energy: 500 }.freeze
  STARTING_FLEET = { "light_fighter" => 10, "transport" => 3 }.freeze
  HOME_SYSTEM = { kind: "home", metal_rate: 30, crystal_rate: 30, energy_rate: 30, defense_strength: 50 }.freeze

  def initialize(galaxy:, user:, name:, role:)
    @galaxy = galaxy
    @user = user
    @name = name
    @role = role
  end

  def call
    ActiveRecord::Base.transaction do
      player = @galaxy.players.create!(user: @user, name: @name)
      system = claim_home_system
      empire = create_empire(player, system)

      # npc_faction is cleared explicitly: on small galaxies the ring can fall on an
      # NPC-held system, and leaving the faction set would make an owned home system
      # still read as hostile to combat resolution and the map.
      system.update!(empire: empire, npc_faction: nil, **HOME_SYSTEM)
      create_planet(empire, system)
      create_starting_fleet(empire, system)

      empire
    end
  end

  private

  def create_planet(empire, system)
    planet = Planet.create!(empire: empire, system: system, name: planet_name(system))

    Structure::STARTING_LEVELS.each do |kind, level|
      planet.structures.create!(kind: kind, level: level)
    end

    planet
  end

  # Home worlds get a name of their own; captured systems keep their coordinates.
  def planet_name(system)
    "#{@name}'s World (#{system.coordinate})"
  end

  def claim_home_system
    HomeSystemPlacement.new(@galaxy).next_free_system ||
      raise(NoHomeSystemAvailable, "this galaxy has no unclaimed systems left")
  end

  def create_empire(player, system)
    @galaxy.empires.create!(player: player, role: @role, home_system: system, **STARTING_RESOURCES)
  end

  def create_starting_fleet(empire, system)
    @galaxy.fleets.create!(
      empire: empire,
      origin_system: system,
      arrival_tick: @galaxy.current_tick,
      status: "orbiting",
      ships: STARTING_FLEET.dup
    )
  end
end
