class GalaxyGenerator
  FACTIONS = [
    { name: "Rim Marauders", color: "#ef4444", strength: 1 },
    { name: "Iron Covenant", color: "#f97316", strength: 3 },
    { name: "Void Hegemony", color: "#a855f7", strength: 5 },
    { name: "Core Imperium", color: "#dc2626", strength: 8 }
  ].freeze

  def initialize(name:, width: 21, height: 21, player_configs: [])
    @name = name
    @width = width
    @height = height
    @player_configs = player_configs
  end

  def generate
    ActiveRecord::Base.transaction do
      galaxy = create_galaxy
      factions = create_factions(galaxy)
      create_sectors(galaxy, factions)
      create_players_and_empires(galaxy)
      galaxy
    end
  end

  private

  def create_galaxy
    Galaxy.create!(
      name: @name,
      width: @width,
      height: @height,
      current_tick: 0,
      status: :active
    )
  end

  def create_factions(galaxy)
    FACTIONS.map do |config|
      galaxy.npc_factions.create!(
        name: config[:name],
        color: config[:color],
        strength_level: config[:strength],
        tech_level: config[:strength]
      )
    end
  end

  def create_sectors(galaxy, factions)
    center_x = galaxy.center[:x]
    center_y = galaxy.center[:y]
    max_distance = distance(center_x, center_y, 0, 0)

    (@width * @height).times do |index|
      x = index % @width
      y = index / @width
      dist = distance(x, y, center_x, center_y)
      normalized = [ dist / max_distance, 1.0 ].min

      sector_attrs = sector_for(galaxy, x, y, normalized, factions)
      galaxy.sectors.create!(sector_attrs)
    end
  end

  def sector_for(galaxy, x, y, normalized_distance, factions)
    base = {
      galaxy: galaxy,
      x: x,
      y: y,
      name: "Sector #{x}-#{y}"
    }

    if x == galaxy.center[:x] && y == galaxy.center[:y]
      return base.merge(
        kind: "core",
        npc_faction: factions.last,
        metal_rate: 100,
        crystal_rate: 100,
        energy_rate: 100,
        defense_strength: 500
      )
    end

    roll = Random.rand

    if normalized_distance < 0.25
      base.merge(
        kind: "fortress",
        npc_faction: faction_for(factions, normalized_distance),
        metal_rate: 60,
        crystal_rate: 60,
        energy_rate: 60,
        defense_strength: (200 + Random.rand(100))
      )
    elsif normalized_distance < 0.5
      if roll < 0.6
        base.merge(
          kind: "outpost",
          npc_faction: faction_for(factions, normalized_distance),
          metal_rate: 40,
          crystal_rate: 40,
          energy_rate: 40,
          defense_strength: (80 + Random.rand(60))
        )
      else
        base.merge(
          kind: "resource",
          metal_rate: 35,
          crystal_rate: 35,
          energy_rate: 35,
          defense_strength: 0
        )
      end
    elsif normalized_distance < 0.75
      if roll < 0.15
        base.merge(
          kind: "outpost",
          npc_faction: faction_for(factions, normalized_distance),
          metal_rate: 25,
          crystal_rate: 25,
          energy_rate: 25,
          defense_strength: (40 + Random.rand(40))
        )
      elsif roll < 0.45
        base.merge(
          kind: "resource",
          metal_rate: 25,
          crystal_rate: 25,
          energy_rate: 25,
          defense_strength: 0
        )
      else
        base.merge(
          kind: "empty",
          metal_rate: 10,
          crystal_rate: 10,
          energy_rate: 10,
          defense_strength: 0
        )
      end
    else
      if roll < 0.25
        base.merge(
          kind: "resource",
          metal_rate: 15,
          crystal_rate: 15,
          energy_rate: 15,
          defense_strength: 0
        )
      else
        base.merge(
          kind: "empty",
          metal_rate: 5,
          crystal_rate: 5,
          energy_rate: 5,
          defense_strength: 0
        )
      end
    end
  end

  def faction_for(factions, normalized_distance)
    index = (normalized_distance * factions.size).floor
    factions[[ index, factions.size - 1 ].min]
  end

  def create_players_and_empires(galaxy)
    home_positions = home_sector_positions(galaxy)

    @player_configs.each_with_index do |config, index|
      player = Player.create!(name: config[:name])
      x, y = home_positions[index]
      sector = galaxy.sectors.at(x, y).first!

      empire = galaxy.empires.create!(
        player: player,
        role: config[:role],
        home_sector: sector,
        metal: 500,
        crystal: 500,
        energy: 500,
        password: config[:password] || "eventide"
      )

      sector.update!(
        kind: "home",
        empire: empire,
        metal_rate: 30,
        crystal_rate: 30,
        energy_rate: 30,
        defense_strength: 50
      )

      galaxy.fleets.create!(
        empire: empire,
        origin_sector: sector,
        target_sector: nil,
        arrival_tick: galaxy.current_tick,
        status: "orbiting",
        ships: { "Fighter" => 10 }
      )
    end
  end

  def home_sector_positions(galaxy)
    cx = galaxy.center[:x]
    cy = galaxy.center[:y]
    radius = [ cx, cy ].min - 2
    count = @player_configs.size

    count.times.map do |i|
      angle = (2 * Math::PI * i) / count
      [
        (cx + radius * Math.cos(angle)).round,
        (cy + radius * Math.sin(angle)).round
      ]
    end
  end

  def distance(x1, y1, x2, y2)
    Math.sqrt((x1 - x2) ** 2 + (y1 - y2) ** 2)
  end
end
