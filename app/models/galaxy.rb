class Galaxy < ApplicationRecord
  # A session's size is chosen when it is created and never changes. Growing a galaxy
  # under players who have already explored it would mean seeding new space into
  # somewhere they may already have scouted.
  #
  # Size buys engagements and room to explore, not duration: travel is cheap even at
  # 400 wide. What makes a season long is how much there is to fight.
  #
  # dimension is the grid edge the disc is inscribed in; npc_systems is how many systems
  # the factions garrison, which is the real campaign-length dial; sectors is how many
  # regions the disc is carved into, which is roughly how many factions a run has.
  SIZES = {
    "tiny" => { dimension: 40, npc_systems: 60, sectors: 5 },
    "small" => { dimension: 150, npc_systems: 540, sectors: 12 },
    "medium" => { dimension: 250, npc_systems: 900, sectors: 18 },
    "large" => { dimension: 400, npc_systems: 1_400, sectors: 26 }
  }.freeze

  # What a session-creation screen offers. `tiny` exists for tests and local poking and
  # is far too small to play a campaign in.
  PLAYABLE_SIZES = %w[small medium large].freeze

  has_many :systems, dependent: :destroy
  has_many :sectors, dependent: :destroy
  has_many :players, dependent: :destroy
  has_many :empires, dependent: :destroy
  has_many :npc_factions, dependent: :destroy
  has_many :fleets, dependent: :destroy

  validates :name, presence: true
  validates :width, :height, numericality: { greater_than: 0 }
  validates :size, inclusion: { in: SIZES.keys }

  enum :status, { active: "active", paused: "paused", completed: "completed" }, default: :active

  def self.dimension_for(size)
    SIZES.fetch(size.to_s)[:dimension]
  end

  def self.npc_systems_for(size)
    SIZES.fetch(size.to_s)[:npc_systems]
  end

  def self.sector_count_for(size)
    SIZES.fetch(size.to_s)[:sectors]
  end

  def center
    { x: width / 2, y: height / 2 }
  end

  # The galaxy is the disc inscribed in the grid, so the radius is the distance from the
  # centre to the nearest edge. Corners are outside it and hold no systems at all —
  # a map with corners has dead space nobody has a reason to visit.
  def radius
    [ center[:x], center[:y] ].min.to_f
  end

  # Where the campaign is pushing toward. It sits out near the rim rather than in the
  # middle: with a central core each player only ever cares about the wedge between their
  # spawn and the centre, and the rest of the disc goes unexplored.
  def core
    { x: core_x, y: core_y }
  end

  def inside?(x, y)
    Math.sqrt(((x - center[:x])**2) + ((y - center[:y])**2)) <= radius
  end

  def spawn_sector
    sectors.find_by(kind: "spawn")
  end

  def core_sector
    sectors.find_by(kind: "core")
  end
end
