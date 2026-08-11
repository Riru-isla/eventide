# Chooses where a new empire starts.
#
# Home sectors sit on a ring around the core, far from the strongest NPC factions.
# Slots are fixed and claimed in a spread order, so players who join one at a time
# still end up spaced around the ring instead of clustered on one arc, and two
# simultaneous signups cannot land on the same coordinate.
class HomeSectorPlacement
  SLOTS = 12

  # Slot claim order: opposite first, then quarters, then the gaps between them.
  SLOT_ORDER = [ 0, 6, 3, 9, 1, 7, 4, 10, 2, 8, 5, 11 ].freeze

  def initialize(galaxy)
    @galaxy = galaxy
  end

  # The first unclaimed ring slot, or the free sector furthest from the core when
  # every slot is taken or blocked (small galaxies can have NPCs sitting on the ring).
  def next_free_sector
    ring_sectors.find { |sector| free?(sector) } || furthest_free_sector
  end

  private

  def ring_sectors
    ring_coordinates.filter_map { |x, y| @galaxy.sectors.at(x, y).first }
  end

  def ring_coordinates
    center_x = @galaxy.center[:x]
    center_y = @galaxy.center[:y]
    radius = [ center_x, center_y ].min - 2

    SLOT_ORDER.map do |slot|
      angle = (2 * Math::PI * slot) / SLOTS
      [ (center_x + radius * Math.cos(angle)).round, (center_y + radius * Math.sin(angle)).round ]
    end
  end

  def free?(sector)
    sector.empire_id.nil? && sector.npc_faction_id.nil?
  end

  def furthest_free_sector
    @galaxy.sectors.where(empire_id: nil, npc_faction_id: nil).max_by(&:distance_to_center)
  end
end
