class Galaxy < ApplicationRecord
  # A session's size is chosen when it is created and never changes. Growing a galaxy
  # under players who have already explored it would mean seeding new space into
  # somewhere they may already have scouted.
  #
  # Size buys engagements and room to explore, not duration: travel is cheap even at
  # 400 wide. What makes a season long is how much there is to fight.
  # dimension is the grid edge; npc_systems is how many systems the factions hold, which
  # is the real campaign-length dial — roughly how many fights lie between a player and
  # the core. It grows sub-linearly with area, so a large galaxy is more to explore
  # rather than proportionally more to grind.
  SIZES = {
    "tiny" => { dimension: 40, npc_systems: 60 },
    "small" => { dimension: 150, npc_systems: 540 },
    "medium" => { dimension: 250, npc_systems: 900 },
    "large" => { dimension: 400, npc_systems: 1_400 }
  }.freeze

  # What a session-creation screen offers. `tiny` exists for tests and local poking and
  # is far too small to play a campaign in.
  PLAYABLE_SIZES = %w[small medium large].freeze

  has_many :systems, dependent: :destroy
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

  def center
    { x: width / 2, y: height / 2 }
  end

  # The scale bands are measured against: the distance from the centre to the nearest
  # edge, not to a corner.
  #
  # Normalising by the corner distance would mean the outer bands only exist diagonally
  # — on a 150x150 the corners are 106 away but the edge midpoints only 75, so an
  # "outermost 14%" would be four corner wedges rather than a ring. Using the inscribed
  # radius makes every band a complete ring; the corners simply sit past 1.0.
  def radius
    [ center[:x], center[:y] ].min.to_f
  end

  # The tier a player is currently up against — the outermost faction still standing.
  def frontier_faction
    npc_factions.standing.order(:tier).first
  end
end
