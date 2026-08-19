# Chooses where a new empire starts.
#
# Home systems sit out on the rim, inside the player band that generation deliberately
# leaves clear of NPCs — so the first hostile system is a push inward rather than a
# neighbour. Slots are fixed and claimed in a spread order, so players joining one at a
# time still end up spaced around the ring, and two simultaneous signups cannot land on
# the same coordinate.
#
# Team-based clustering replaces this ordering in the next step; for now the job is to
# keep spawns out of the faction bands.
class HomeSystemPlacement
  SLOTS = 24

  # Claim order: opposite first, then quarters, then the gaps between, so the first few
  # commanders are as far apart as the ring allows.
  SLOT_ORDER = [
    0, 12, 6, 18, 3, 15, 9, 21, 1, 13, 7, 19,
    4, 16, 10, 22, 2, 14, 8, 20, 5, 17, 11, 23
  ].freeze

  # Where in the player band the ring sits. Far enough out to stay clear of tier 1,
  # far enough in to leave somewhere to retreat to.
  RING_POSITION = 0.93

  def initialize(galaxy)
    @galaxy = galaxy
  end

  # The first unclaimed ring slot, or the nearest free system to the ring when every
  # slot is taken.
  def next_free_system
    ring_systems.find { |system| free?(system) } || nearest_free_to_ring
  end

  private

  def ring_systems
    ring_coordinates.filter_map { |x, y| @galaxy.systems.at(x, y).first }
  end

  def ring_coordinates
    centre_x = @galaxy.center[:x]
    centre_y = @galaxy.center[:y]
    radius = @galaxy.radius * RING_POSITION

    SLOT_ORDER.map do |slot|
      angle = (2 * Math::PI * slot) / SLOTS
      [
        (centre_x + (radius * Math.cos(angle))).round.clamp(0, @galaxy.width - 1),
        (centre_y + (radius * Math.sin(angle))).round.clamp(0, @galaxy.height - 1)
      ]
    end
  end

  def free?(system)
    system.empire_id.nil? && system.npc_faction_id.nil?
  end

  # Falls back toward the ring rather than out to a corner: a latecomer should start
  # beside everyone else, not half a galaxy further from the core.
  def nearest_free_to_ring
    target = @galaxy.radius * RING_POSITION

    @galaxy.systems.where(empire_id: nil, npc_faction_id: nil)
           .min_by { |system| (system.distance_to_center - target).abs }
  end
end
