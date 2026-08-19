class Galaxy < ApplicationRecord
  # A session's size is chosen when it is created and never changes. Growing a galaxy
  # under players who have already explored it would mean seeding new space into
  # somewhere they may already have scouted.
  #
  # Size buys engagements and room to explore, not duration: travel is cheap even at
  # 400 wide. What makes a season long is how much there is to fight.
  #
  # dimension is the grid edge the disc is inscribed in; npc_systems is how many systems
  # the factions garrison between them, which is the real campaign-length dial; factions
  # is what the new-galaxy form suggests for that size, not a limit.
  SIZES = {
    "tiny" => { dimension: 40, npc_systems: 60, factions: 4 },
    "small" => { dimension: 150, npc_systems: 540, factions: 11 },
    "medium" => { dimension: 250, npc_systems: 900, factions: 17 },
    "large" => { dimension: 400, npc_systems: 1_400, factions: 25 }
  }.freeze

  # Fewer than four and there is no campaign: the ladder needs a rim to open on, a couple
  # of steps, and a core to finish at.
  MINIMUM_FACTIONS = 4
  # Past this, sectors on a small map are too thin to be territory.
  MAXIMUM_FACTIONS = 40

  # Only one for now. It exists as a column so a game mode that changes what winning means
  # is a new entry here rather than a migration.
  VICTORY_CONDITIONS = { "reach_the_core" => "Reach the core" }.freeze

  # How hard a garrison hits, as a multiplier on defence.
  THREAT_LEVELS = { "calm" => 0.6, "standard" => 1.0, "harsh" => 1.6, "brutal" => 2.4 }.freeze

  # How readily factions notice players, as a multiplier on each faction's awareness.
  AWARENESS_LEVELS = { "oblivious" => 0.5, "standard" => 1.0, "alert" => 1.5, "paranoid" => 2.0 }.freeze

  # What the galaxy does while nobody is pushing it.
  #
  # `chill` is the default and the honest one: nothing anywhere has a clock until a
  # commander makes the first move, so a group that plays two hours a day is never
  # overtaken by an escalation they did not provoke. `restless` gives up that guarantee
  # deliberately — the factions on your border start counting down at tick zero, and the
  # war begins whether or not you begin it.
  STRESS_LEVELS = {
    "chill" => "Chill — nothing stirs until provoked",
    "restless" => "Restless — the frontier wakes on its own"
  }.freeze

  # What becomes of a faction's territory once its capital is taken. One outcome for now;
  # the column exists so alternatives are an entry here rather than a migration.
  FALLEN_OUTCOMES = {
    "decay" => "Survivors go idle and decay"
  }.freeze

  # What a session-creation screen offers. `tiny` exists for tests and local poking and
  # is far too small to play a campaign in.
  PLAYABLE_SIZES = %w[small medium large].freeze

  # Order matters on destroy. A faction's capital_system_id is a real foreign key, so
  # factions have to go before the systems they point at; systems reference sectors, so
  # they go before those.
  has_many :npc_factions, dependent: :destroy
  has_many :systems, dependent: :destroy
  has_many :sectors, dependent: :destroy
  has_many :fleets, dependent: :destroy
  has_many :empires, dependent: :destroy
  has_many :players, dependent: :destroy

  validates :name, presence: true
  validates :width, :height, numericality: { greater_than: 0 }
  validates :size, inclusion: { in: SIZES.keys }
  validates :victory_condition, inclusion: { in: VICTORY_CONDITIONS.keys }
  validates :threat_level, inclusion: { in: THREAT_LEVELS.keys }
  validates :awareness_level, inclusion: { in: AWARENESS_LEVELS.keys }
  validates :stress_level, inclusion: { in: STRESS_LEVELS.keys }
  validates :fallen_outcome, inclusion: { in: FALLEN_OUTCOMES.keys }
  validates :faction_count,
            numericality: { only_integer: true, greater_than_or_equal_to: MINIMUM_FACTIONS,
                            less_than_or_equal_to: MAXIMUM_FACTIONS }
  validates :team_count, numericality: { only_integer: true, greater_than: 0 }

  enum :status, { active: "active", paused: "paused", completed: "completed" }, default: :active

  def self.dimension_for(size)
    SIZES.fetch(size.to_s)[:dimension]
  end

  def self.npc_systems_for(size)
    SIZES.fetch(size.to_s)[:npc_systems]
  end

  def self.faction_count_for(size)
    SIZES.fetch(size.to_s)[:factions]
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

  def threat_multiplier
    THREAT_LEVELS.fetch(threat_level)
  end

  # Whether the galaxy escalates without being provoked.
  def restless?
    stress_level != "chill"
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
