# Chooses where a new empire starts.
#
# Everybody shares one spawn sector, out at the far end of the disc from the core, so the
# whole group has a single frontier and shipments between players stay cheap. Within it,
# commanders are packed toward the sector's heart rather than spread to its edges — the
# point of a shared sector is that people can reach each other — but never closer to one
# another than MINIMUM_GAP, or two of them end up in each other's laps.
class HomeSystemPlacement
  MINIMUM_GAP = 6

  def initialize(galaxy)
    @galaxy = galaxy
  end

  def next_free_system
    candidates = free_systems
    return nil if candidates.empty?

    claimed = @galaxy.systems.where(kind: "home").to_a
    return closest_to_heart(candidates) if claimed.empty?

    spaced = candidates.select { |system| gap_from(system, claimed) >= MINIMUM_GAP }
    return closest_to_heart(spaced) if spaced.any?

    # Too crowded to keep the gap. Better a tight squeeze than refusing to seat a
    # commander who has just signed up.
    candidates.max_by { |system| gap_from(system, claimed) }
  end

  private

  def free_systems
    scope = @galaxy.spawn_sector&.systems || @galaxy.systems

    scope.where(empire_id: nil, npc_faction_id: nil).to_a
  end

  def gap_from(system, claimed)
    claimed.map { |home| system.distance_to(home.x, home.y) }.min
  end

  # A sector's seed is its deepest point, so working outward from there keeps the group
  # together in the middle of their own territory.
  def closest_to_heart(candidates)
    sector = @galaxy.spawn_sector
    return candidates.first if sector.nil?

    candidates.min_by { |system| system.distance_to(sector.seed_x, sector.seed_y) }
  end
end
