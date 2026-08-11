# Creates everything a new commander needs: a player, an empire, a claimed home
# sector, and a starting fleet.
#
# Galaxy seeding and player signup both go through here so that a seeded demo
# empire and one created from the signup form are identical.
class EmpireFounder
  class NoHomeSectorAvailable < StandardError; end

  STARTING_RESOURCES = { metal: 500, crystal: 500, energy: 500 }.freeze
  STARTING_FLEET = { "Fighter" => 10 }.freeze
  HOME_SECTOR = { kind: "home", metal_rate: 30, crystal_rate: 30, energy_rate: 30, defense_strength: 50 }.freeze

  def initialize(galaxy:, user:, name:, role:)
    @galaxy = galaxy
    @user = user
    @name = name
    @role = role
  end

  def call
    ActiveRecord::Base.transaction do
      player = @galaxy.players.create!(user: @user, name: @name)
      sector = claim_home_sector
      empire = create_empire(player, sector)

      # npc_faction is cleared explicitly: on small galaxies the ring can fall on an
      # NPC-held sector, and leaving the faction set would make an owned home sector
      # still read as hostile to combat resolution and the map.
      sector.update!(empire: empire, npc_faction: nil, **HOME_SECTOR)
      create_planet(empire, sector)
      create_starting_fleet(empire, sector)

      empire
    end
  end

  private

  def create_planet(empire, sector)
    planet = Planet.create!(empire: empire, sector: sector, name: planet_name(sector))

    Structure::STARTING_LEVELS.each do |kind, level|
      planet.structures.create!(kind: kind, level: level)
    end

    planet
  end

  # Home worlds get a name of their own; captured sectors keep their coordinates.
  def planet_name(sector)
    "#{@name}'s World (#{sector.coordinate})"
  end

  def claim_home_sector
    HomeSectorPlacement.new(@galaxy).next_free_sector ||
      raise(NoHomeSectorAvailable, "this galaxy has no unclaimed sectors left")
  end

  def create_empire(player, sector)
    @galaxy.empires.create!(player: player, role: @role, home_sector: sector, **STARTING_RESOURCES)
  end

  def create_starting_fleet(empire, sector)
    @galaxy.fleets.create!(
      empire: empire,
      origin_sector: sector,
      arrival_tick: @galaxy.current_tick,
      status: "orbiting",
      ships: STARTING_FLEET.dup
    )
  end
end
