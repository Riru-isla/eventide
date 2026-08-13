# Builds a session's galaxy: the grid, the NPC factions that hold it, and their capitals.
#
# Bands are measured from the **rim inward**, so the faction a player meets first is the
# weakest one. Each tier inward holds more sectors and defends them harder, so difficulty
# compounds on both axes rather than only one.
#
# The previous version mapped distance to faction index directly, which put the weakest
# faction on the fortress ring next to the core and the strongest out on the sparse rim.
class GalaxyGenerator
  # Ordered outermost first. `share` is the slice of the NPC budget a tier holds, and
  # `defence` the base strength of an ordinary sector it owns.
  #
  # These are a starting point. Nothing has been fought yet, so they want tuning once
  # somebody has actually pushed a fleet into a band.
  TIERS = [
    { tier: 1, name: "Rim Marauders", color: "#ef4444", share: 0.08, defence: 60,    strength: 1 },
    { tier: 2, name: "Iron Covenant", color: "#f97316", share: 0.11, defence: 160,   strength: 3 },
    { tier: 3, name: "Void Hegemony", color: "#a855f7", share: 0.17, defence: 420,   strength: 5 },
    { tier: 4, name: "Crimson Pact",  color: "#e879b8", share: 0.26, defence: 1_100, strength: 8 },
    { tier: 5, name: "Core Imperium", color: "#dc2626", share: 0.38, defence: 2_800, strength: 13 }
  ].freeze

  # A capital is this many times tougher than an ordinary sector of its tier.
  CAPITAL_DEFENCE_MULTIPLIER = 6

  # Players spawn in this outermost slice of the map, which holds no NPCs at all.
  PLAYER_BAND = 0.14

  # Rows written per INSERT. A 400x400 galaxy is 160,000 sectors; one statement each
  # would take minutes.
  BATCH_SIZE = 2_000

  def initialize(name:, size: "small", player_configs: [])
    @name = name
    @size = size.to_s
    @dimension = Galaxy.dimension_for(@size)
    @npc_sectors = Galaxy.npc_sectors_for(@size)
    @player_configs = player_configs
  end

  def generate
    galaxy = nil

    ActiveRecord::Base.transaction do
      galaxy = create_galaxy
      factions = create_factions(galaxy)
      create_sectors(galaxy, factions)
      assign_capitals(galaxy, factions)
      create_players_and_empires(galaxy)
    end

    galaxy
  end

  private

  def create_galaxy
    Galaxy.create!(
      name: @name, size: @size,
      width: @dimension, height: @dimension,
      current_tick: 0, status: :active
    )
  end

  def create_factions(galaxy)
    TIERS.to_h do |config|
      faction = galaxy.npc_factions.create!(
        name: config[:name], color: config[:color], tier: config[:tier],
        strength_level: config[:strength], tech_level: config[:strength],
        # Only the faction on the frontier knows players exist. The rest wake as the
        # band outside them falls.
        aggression: config[:tier] == 1 ? :dormant : :unaware
      )

      [ config[:tier], faction ]
    end
  end

  # Every coordinate becomes a row, built in memory and bulk inserted.
  #
  # A tier's holdings are drawn at random from across the whole width of its band. Taking
  # the innermost coordinates instead would spend the budget on one ring and leave the
  # rest of the band empty, so each faction would be a hoop rather than territory.
  def create_sectors(galaxy, factions)
    coordinates = coordinates_by_tier(galaxy)
    held = claimed_coordinates(coordinates)
    now = Time.current
    rows = []

    coordinates.each do |tier, points|
      points.each do |x, y, normalized|
        rows << if core?(galaxy, x, y)
          core_sector(galaxy, x, y, factions, now)
        elsif held.include?([ x, y ])
          npc_sector(galaxy, x, y, factions[tier], now)
        else
          open_sector(galaxy, x, y, normalized, now)
        end
      end
    end

    rows.each_slice(BATCH_SIZE) { |slice| Sector.insert_all!(slice) }
  end

  # Every coordinate grouped by the tier whose band it falls in; nil for open space.
  def coordinates_by_tier(galaxy)
    centre = galaxy.center
    radius = galaxy.radius

    (0...@dimension).flat_map { |y|
      (0...@dimension).map do |x|
        normalized = Math.sqrt(((x - centre[:x])**2) + ((y - centre[:y])**2)) / radius
        [ tier_at(normalized), x, y, normalized ]
      end
    }.group_by(&:first).transform_values { |points| points.map { |entry| entry[1..] } }
  end

  # Which coordinates each faction actually holds: its budget, sampled from anywhere in
  # its band so holdings are scattered through the depth of it.
  def claimed_coordinates(coordinates)
    tier_budgets.flat_map { |tier, budget|
      (coordinates[tier] || []).sample(budget).map { |x, y, _| [ x, y ] }
    }.to_set
  end

  def tier_budgets
    TIERS.to_h { |config| [ config[:tier], (@npc_sectors * config[:share]).round ] }
  end

  # Which tier owns a given distance. Tier 5 sits against the core and tier 1 just
  # inside the player band; anything further out is open space.
  def tier_at(normalized)
    return nil if normalized > (1.0 - PLAYER_BAND)

    span = (1.0 - PLAYER_BAND) / TIERS.size
    index = (normalized / span).floor.clamp(0, TIERS.size - 1)

    TIERS.size - index
  end

  def core?(galaxy, x, y)
    x == galaxy.center[:x] && y == galaxy.center[:y]
  end

  def npc_sector(galaxy, x, y, faction, now)
    config = TIERS.find { |c| c[:tier] == faction.tier }

    base_sector(galaxy, x, y, now).merge(
      kind: "outpost",
      npc_faction_id: faction.id,
      metal_rate: 20 + (faction.tier * 12),
      crystal_rate: 20 + (faction.tier * 12),
      energy_rate: 0,
      defense_strength: config[:defence] + Random.rand(config[:defence] / 4)
    )
  end

  def open_sector(galaxy, x, y, normalized, now)
    # Richer deposits nearer the core, so pushing inward is worth it for more than
    # just reaching the middle.
    richness = ((1.0 - normalized) * 30).round
    resource = Random.rand < 0.25

    base_sector(galaxy, x, y, now).merge(
      kind: resource ? "resource" : "empty",
      npc_faction_id: nil,
      metal_rate: resource ? richness + 10 : (richness / 3),
      crystal_rate: resource ? richness + 10 : (richness / 3),
      energy_rate: 0,
      defense_strength: 0
    )
  end

  def core_sector(galaxy, x, y, factions, now)
    base_sector(galaxy, x, y, now).merge(
      kind: "core",
      npc_faction_id: factions[TIERS.last[:tier]].id,
      metal_rate: 200, crystal_rate: 200, energy_rate: 0,
      defense_strength: TIERS.last[:defence] * CAPITAL_DEFENCE_MULTIPLIER
    )
  end

  def base_sector(galaxy, x, y, now)
    { galaxy_id: galaxy.id, x: x, y: y, name: "Sector #{x}-#{y}", created_at: now, updated_at: now }
  end

  # Each faction's capital is the sector it holds closest to the core: the deepest and
  # best defended point of its band, and the objective that ends the tier.
  def assign_capitals(galaxy, factions)
    centre = galaxy.center

    factions.each_value do |faction|
      capital = galaxy.sectors.where(npc_faction_id: faction.id).where.not(kind: "core")
                      .min_by { |sector| sector.distance_to(centre[:x], centre[:y]) }
      capital ||= galaxy.sectors.find_by(npc_faction_id: faction.id)
      next if capital.nil?

      capital.update!(
        kind: "fortress",
        defense_strength: capital.defense_strength * CAPITAL_DEFENCE_MULTIPLIER
      )
      faction.update!(capital_sector: capital)
    end
  end

  def create_players_and_empires(galaxy)
    @player_configs.each do |config|
      user = User.create!(
        username: config[:username] || config[:name].downcase,
        password: config[:password] || "eventide"
      )

      EmpireFounder.new(galaxy: galaxy, user: user, name: config[:name], role: config[:role]).call
    end
  end
end
