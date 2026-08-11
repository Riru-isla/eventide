# Static catalogue of empire-wide research, in the same spirit as Structure: these are
# balance numbers, so they live in code with specs rather than in a table.
#
# Unlike structures, technologies have **prerequisites** — a required Research Center
# level and, for the deeper ones, levels in other technologies. That is what turns the
# list into a tree.
class Technology
  CATEGORIES = %w[economy military propulsion].freeze

  # Research is meant to be a heavier commitment than a building, so it doubles.
  COST_GROWTH = 2.0
  TIME_GROWTH = 1.8

  # Each Research Center level above the first speeds research up by this much.
  CENTER_SPEEDUP_PER_LEVEL = 0.10
  MINIMUM_RESEARCH_SPEED = 0.25

  attr_reader :key, :name, :category, :summary, :effect, :bonus_per_level,
              :base_metal_cost, :base_crystal_cost, :base_ticks,
              :requires_center, :requires

  def initialize(key:, name:, category:, summary:, effect:, bonus_per_level:,
                 base_metal_cost:, base_crystal_cost:, base_ticks:,
                 requires_center: 1, requires: {})
    @key = key
    @name = name
    @category = category
    @summary = summary
    @effect = effect
    @bonus_per_level = bonus_per_level
    @base_metal_cost = base_metal_cost
    @base_crystal_cost = base_crystal_cost
    @base_ticks = base_ticks
    @requires_center = requires_center
    @requires = requires.freeze
  end

  ALL = [
    new(
      key: "extraction_technology", name: "Extraction Technology", category: "economy",
      summary: "Better drill heads and separation. Adds 5% to every extractor's yield per level.",
      effect: :extraction_yield, bonus_per_level: 0.05,
      base_metal_cost: 400, base_crystal_cost: 200, base_ticks: 10,
      requires_center: 1
    ),
    new(
      key: "energy_technology", name: "Energy Technology", category: "economy",
      summary: "Higher-efficiency conversion. Adds 5% to this empire's energy production per level.",
      effect: :energy_output, bonus_per_level: 0.05,
      base_metal_cost: 300, base_crystal_cost: 400, base_ticks: 10,
      requires_center: 1
    ),
    new(
      key: "storage_technology", name: "Storage Technology", category: "economy",
      summary: "Denser packing and better containment. Adds 10% to every silo's capacity per level.",
      effect: :storage, bonus_per_level: 0.10,
      base_metal_cost: 250, base_crystal_cost: 150, base_ticks: 8,
      requires_center: 1
    ),
    new(
      key: "construction_technology", name: "Construction Technology", category: "economy",
      summary: "Prefabrication and better logistics. Cuts 3% from all construction time per level.",
      effect: :build_speed, bonus_per_level: 0.03,
      base_metal_cost: 500, base_crystal_cost: 350, base_ticks: 14,
      requires_center: 2, requires: { "extraction_technology" => 2 }
    ),
    new(
      key: "propulsion_technology", name: "Propulsion Technology", category: "propulsion",
      summary: "Stronger drives. Cuts 5% from fleet travel time per level.",
      effect: :propulsion, bonus_per_level: 0.05,
      base_metal_cost: 450, base_crystal_cost: 300, base_ticks: 12,
      requires_center: 2, requires: { "energy_technology" => 1 }
    ),
    new(
      key: "weapons_technology", name: "Weapons Technology", category: "military",
      summary: "Heavier ordnance across the fleet. Adds 5% to fleet attack power per level.",
      effect: :weapons, bonus_per_level: 0.05,
      base_metal_cost: 500, base_crystal_cost: 250, base_ticks: 12,
      requires_center: 2
    ),
    new(
      key: "armor_technology", name: "Armor Technology", category: "military",
      summary: "Reinforced hulls. Lets 10% of a fleet per level survive a failed attack and " \
               "limp home, instead of being lost entirely.",
      effect: :armor, bonus_per_level: 0.10,
      base_metal_cost: 600, base_crystal_cost: 200, base_ticks: 12,
      requires_center: 2
    ),
    new(
      key: "laser_technology", name: "Laser Technology", category: "military",
      summary: "Focused beam weapons. Adds a further 8% to fleet attack power per level, on top " \
               "of Weapons Technology.",
      effect: :weapons, bonus_per_level: 0.08,
      base_metal_cost: 900, base_crystal_cost: 700, base_ticks: 20,
      requires_center: 3, requires: { "energy_technology" => 2, "weapons_technology" => 2 }
    )
  ].freeze

  BY_KEY = ALL.index_by(&:key).freeze
  KEYS = ALL.map(&:key).freeze

  class << self
    def all = ALL
    def keys = KEYS
    def find(key) = BY_KEY[key]
    def find!(key) = BY_KEY.fetch(key)
    def in_category(category) = ALL.select { |technology| technology.category == category }
    def with_effect(effect) = ALL.select { |technology| technology.effect == effect }
  end

  # Cost of raising the technology from `level` to `level + 1`.
  def research_cost(level)
    factor = COST_GROWTH**level

    {
      metal: (base_metal_cost * factor).round,
      crystal: (base_crystal_cost * factor).round
    }
  end

  def research_ticks(level, speed_multiplier: 1.0)
    [ (base_ticks * TIME_GROWTH**level * speed_multiplier).ceil, 1 ].max
  end

  # Prerequisites as readable text, for the locked state on the research screen.
  def requirement_labels
    labels = [ "Research Center #{requires_center}" ]
    labels + requires.map { |key, level| "#{Technology.find!(key).name} #{level}" }
  end
end
