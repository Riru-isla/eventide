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

  # And takes this much longer to build.
  BUILD_GROWTH = 1.45

  # Storage a planet has with no silo at all, and how much each silo level multiplies it.
  # Crew Quarters override both: crew is scarce and scales far more slowly.
  BASE_STORAGE = 10_000
  STORAGE_GROWTH = 1.75

  # Yield a refinery adds per level, as a fraction of the extractor's raw output.
  YIELD_BONUS_PER_LEVEL = 0.10

  # Construction time removed per Robotics Bay level.
  BUILD_SPEED_PER_LEVEL = 0.05

  attr_reader :key, :name, :category, :summary, :resource, :effect,
              :energy_draw_per_level, :energy_output_per_level, :crew_per_level,
              :base_storage, :storage_growth,
              :base_metal_cost, :base_crystal_cost, :base_build_ticks

  def initialize(key:, name:, category:, summary:, base_metal_cost:, base_crystal_cost:,
                 base_build_ticks: 2, resource: nil, energy_draw_per_level: 0,
                 energy_output_per_level: 0, crew_per_level: 0, effect: nil,
                 base_storage: BASE_STORAGE, storage_growth: STORAGE_GROWTH)
    @key = key
    @name = name
    @category = category
    @summary = summary
    @resource = resource
    @energy_draw_per_level = energy_draw_per_level
    @energy_output_per_level = energy_output_per_level
    @crew_per_level = crew_per_level
    @base_storage = base_storage
    @storage_growth = storage_growth
    @base_metal_cost = base_metal_cost
    @base_crystal_cost = base_crystal_cost
    @base_build_ticks = base_build_ticks
    @effect = effect
  end

  ALL = [
    new(
      key: "metal_extractor", name: "Metal Extractor", category: "extraction",
      summary: "Pulls metal from the planet's deposits. Each level multiplies the base yield.",
      resource: :metal, energy_draw_per_level: 34, effect: :extraction,
      base_metal_cost: 60, base_crystal_cost: 15, base_build_ticks: 2
    ),
    new(
      key: "crystal_extractor", name: "Crystal Extractor", category: "extraction",
      summary: "Cuts crystal from the planet's seams. Each level multiplies the base yield.",
      resource: :crystal, energy_draw_per_level: 35, effect: :extraction,
      base_metal_cost: 48, base_crystal_cost: 24, base_build_ticks: 2
    ),
    new(
      key: "solar_array", name: "Solar Array", category: "energy",
      summary: "Generates the energy every other structure draws on. Never throttled.",
      energy_output_per_level: 100, effect: :energy,
      base_metal_cost: 75, base_crystal_cost: 30, base_build_ticks: 2
    ),
    new(
      key: "refinery", name: "Metal Refinery", category: "facility",
      summary: "Refines raw ore on site. Adds 10% to this planet's metal yield per level.",
      resource: :metal, effect: :yield_bonus, energy_draw_per_level: 12,
      base_metal_cost: 120, base_crystal_cost: 80, base_build_ticks: 4
    ),
    new(
      key: "crystal_refinery", name: "Crystal Refinery", category: "facility",
      summary: "Cleans and cuts raw crystal. Adds 10% to this planet's crystal yield per level.",
      resource: :crystal, effect: :yield_bonus, energy_draw_per_level: 12,
      base_metal_cost: 100, base_crystal_cost: 110, base_build_ticks: 4
    ),
    new(
      key: "metal_silo", name: "Metal Silo", category: "facility",
      summary: "Raises how much metal the empire can hold. Income stops once storage is full.",
      resource: :metal, effect: :storage,
      base_metal_cost: 100, base_crystal_cost: 40, base_build_ticks: 3
    ),
    new(
      key: "crystal_silo", name: "Crystal Silo", category: "facility",
      summary: "Raises how much crystal the empire can hold. Income stops once storage is full.",
      resource: :crystal, effect: :storage,
      base_metal_cost: 90, base_crystal_cost: 60, base_build_ticks: 3
    ),
    new(
      key: "pilot_academy", name: "Pilot Academy", category: "facility",
      summary: "Trains the crew every hull needs. Turns out 2 crew per tick per level.",
      resource: :crew, effect: :crew_training, crew_per_level: 2, energy_draw_per_level: 15,
      base_metal_cost: 150, base_crystal_cost: 120, base_build_ticks: 5
    ),
    new(
      key: "crew_quarters", name: "Crew Quarters", category: "facility",
      summary: "Bunks, mess and life support. Raises how many trained crew the empire can hold.",
      resource: :crew, effect: :storage,
      base_storage: 100, storage_growth: 1.35,
      base_metal_cost: 110, base_crystal_cost: 90, base_build_ticks: 4
    ),
    new(
      key: "robotics_bay", name: "Robotics Bay", category: "facility",
      summary: "Automated crews cut 5% from construction time per level.",
      effect: :build_speed, energy_draw_per_level: 10,
      base_metal_cost: 140, base_crystal_cost: 100, base_build_ticks: 5
    ),
    new(
      key: "research_center", name: "Research Center", category: "facility",
      summary: "Where empire-wide research is carried out. Higher levels will unlock and " \
               "speed up technologies once the Research section exists.",
      effect: :research, energy_draw_per_level: 25,
      base_metal_cost: 200, base_crystal_cost: 180, base_build_ticks: 8
    ),
    new(
      key: "shipyard", name: "Shipyard", category: "facility",
      summary: "Required to build ships at this planet. Higher levels unlock larger hulls.",
      energy_draw_per_level: 20, effect: :shipyard,
      base_metal_cost: 90, base_crystal_cost: 60, base_build_ticks: 6
    )
  ].freeze

  BY_KEY = ALL.index_by(&:key).freeze
  KEYS = ALL.map(&:key).freeze

  # Which structure raises yield, and which raises storage, for each resource.
  YIELD_BONUS_KEYS = { metal: "refinery", crystal: "crystal_refinery" }.freeze
  STORAGE_KEYS = { metal: "metal_silo", crystal: "crystal_silo", crew: "crew_quarters" }.freeze
  EXTRACTOR_KEYS = { metal: "metal_extractor", crystal: "crystal_extractor" }.freeze

  # Levels every new planet starts with.
  STARTING_LEVELS = {
    "metal_extractor" => 1,
    "crystal_extractor" => 1,
    "solar_array" => 1,
    "refinery" => 0,
    "crystal_refinery" => 0,
    "metal_silo" => 0,
    "crystal_silo" => 0,
    "pilot_academy" => 0,
    "crew_quarters" => 0,
    "robotics_bay" => 0,
    "research_center" => 0,
    "shipyard" => 1
  }.freeze

  class << self
    def all = ALL
    def keys = KEYS
    def find(key) = BY_KEY[key]
    def find!(key) = BY_KEY.fetch(key)
    def in_category(category) = ALL.select { |structure| structure.category == category }

    def extractor_for(resource) = find!(EXTRACTOR_KEYS.fetch(resource))
    def refinery_for(resource) = find!(YIELD_BONUS_KEYS.fetch(resource))
    def silo_for(resource) = find!(STORAGE_KEYS.fetch(resource))
  end

  def energy_draw(level) = energy_draw_per_level * level

  def energy_output(level) = energy_output_per_level * level

  # How much of its resource this silo lets the empire hold. Level zero is the base
  # capacity every planet has without a silo at all.
  def storage_capacity(level)
    (base_storage * storage_growth**level).round
  end

  # Ticks needed to raise the structure from `level` to `level + 1`. A speed
  # multiplier below 1 (from the Robotics Bay) shortens it.
  def build_ticks(level, speed_multiplier: 1.0)
    [ (base_build_ticks * BUILD_GROWTH**level * speed_multiplier).ceil, 1 ].max
  end

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

  def storage? = effect == :storage

  def yield_bonus? = effect == :yield_bonus
end
