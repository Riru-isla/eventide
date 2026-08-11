# Static catalogue of everything that can be built on a planet.
#
# Kept in Ruby rather than a database table: these are balance numbers, and
# tuning them should be a code change with a spec, not a data migration.
#
# Levels are stored per planet in PlanetStructure; this class only describes what
# a level *means*.
class Structure
  CATEGORIES = %w[extraction energy facility].freeze

  # Each upgrade costs this much more than the one before it.
  COST_GROWTH = 1.6

  attr_reader :key, :name, :category, :summary, :resource,
              :energy_draw_per_level, :energy_output_per_level,
              :base_metal_cost, :base_crystal_cost, :effect

  def initialize(key:, name:, category:, summary:, base_metal_cost:, base_crystal_cost:,
                 resource: nil, energy_draw_per_level: 0, energy_output_per_level: 0, effect: nil)
    @key = key
    @name = name
    @category = category
    @summary = summary
    @resource = resource
    @energy_draw_per_level = energy_draw_per_level
    @energy_output_per_level = energy_output_per_level
    @base_metal_cost = base_metal_cost
    @base_crystal_cost = base_crystal_cost
    @effect = effect
  end

  ALL = [
    new(
      key: "metal_extractor", name: "Metal Extractor", category: "extraction",
      summary: "Pulls metal from the planet's deposits. Each level multiplies the base yield.",
      resource: :metal, energy_draw_per_level: 34,
      base_metal_cost: 60, base_crystal_cost: 15
    ),
    new(
      key: "crystal_extractor", name: "Crystal Extractor", category: "extraction",
      summary: "Cuts crystal from the planet's seams. Each level multiplies the base yield.",
      resource: :crystal, energy_draw_per_level: 35,
      base_metal_cost: 48, base_crystal_cost: 24
    ),
    new(
      key: "solar_array", name: "Solar Array", category: "energy",
      summary: "Generates the energy every other structure draws on. Never throttled.",
      energy_output_per_level: 100,
      base_metal_cost: 75, base_crystal_cost: 30
    ),
    new(
      key: "refinery", name: "Refinery", category: "facility",
      summary: "Refines raw ore on site. Adds 10% to this planet's metal yield per level.",
      base_metal_cost: 120, base_crystal_cost: 80, effect: :metal_bonus
    ),
    new(
      key: "robotics_bay", name: "Robotics Bay", category: "facility",
      summary: "Automated crews cut 5% from construction time per level.",
      base_metal_cost: 140, base_crystal_cost: 100, effect: :build_speed
    ),
    new(
      key: "shipyard", name: "Shipyard", category: "facility",
      summary: "Required to build ships at this planet. Higher levels unlock larger hulls.",
      energy_draw_per_level: 20,
      base_metal_cost: 90, base_crystal_cost: 60, effect: :shipyard
    )
  ].freeze

  BY_KEY = ALL.index_by(&:key).freeze
  KEYS = ALL.map(&:key).freeze

  # Levels every new planet starts with.
  STARTING_LEVELS = {
    "metal_extractor" => 1,
    "crystal_extractor" => 1,
    "solar_array" => 1,
    "refinery" => 0,
    "robotics_bay" => 0,
    "shipyard" => 1
  }.freeze

  # Metal bonus contributed per refinery level.
  METAL_BONUS_PER_LEVEL = 0.10

  # Construction time removed per robotics level.
  BUILD_SPEED_PER_LEVEL = 0.05

  class << self
    def all = ALL
    def keys = KEYS
    def find(key) = BY_KEY[key]
    def find!(key) = BY_KEY.fetch(key)
    def in_category(category) = ALL.select { |structure| structure.category == category }
  end

  def energy_draw(level) = energy_draw_per_level * level

  def energy_output(level) = energy_output_per_level * level

  # Cost of raising the structure from `level` to `level + 1`.
  def upgrade_cost(level)
    factor = COST_GROWTH**level

    {
      metal: (base_metal_cost * factor).round,
      crystal: (base_crystal_cost * factor).round
    }
  end

  def extraction? = category == "extraction"

  def energy? = category == "energy"
end
