# An actor in the galaxy: it holds systems, runs planets, banks resources and sends
# fleets. `empire_type` says whether a commander or the AI is driving.
#
# Factions are empires too, deliberately. It means the AI travels the same code — economy,
# build queue, shipyard, combat — that a player does, so balance cannot quietly diverge
# between them and there are no two sets of rules to keep in step by hand.
class Empire < ApplicationRecord
  # What a commander picks when they join.
  COMMANDER_ROLES = %w[cultivator foundry warden].freeze
  # Factions carry a role of their own rather than a nil, so nothing downstream has to
  # special-case the absence of one. It grants no bonus: a faction's edge is tempo and
  # scale, never yield.
  NPC_ROLE = "npc".freeze
  ROLES = (COMMANDER_ROLES + [ NPC_ROLE ]).freeze

  TYPES = { player: "player", npc: "npc" }.freeze

  # An NPC empire has no account behind it.
  belongs_to :player, optional: true
  belongs_to :galaxy
  belongs_to :home_system, class_name: "System", optional: true
  # The AI's brain, kept apart so the empires table is not a dozen columns of nulls for
  # every human player.
  has_one :npc_faction, dependent: :destroy
  has_many :systems, dependent: :nullify
  has_many :fleets, dependent: :destroy
  has_many :planets, dependent: :destroy
  # Commanders hold exactly one, and most of the app reads it this way. A faction runs
  # several and uses `planets`.
  has_one :planet
  has_many :technologies, class_name: "EmpireTechnology", dependent: :destroy
  # An empire researches one project at a time; research_orders is the plural side used
  # for querying due work, research_order the single project under way.
  has_many :research_orders, dependent: :destroy
  has_one :research_order, dependent: :destroy

  enum :empire_type, TYPES, default: :player, prefix: :run_by

  validates :name, presence: true
  validates :role, inclusion: { in: ROLES }
  validates :metal, :crystal, :energy, numericality: { greater_than_or_equal_to: 0 }

  scope :commanded, -> { where(empire_type: "player") }
  scope :artificial, -> { where(empire_type: "npc") }

  def research
    @research ||= ResearchLab.new(self)
  end

  def technology_level(kind)
    technologies.detect { |record| record.kind == kind }&.level.to_i
  end

  # Every technology with the same effect stacks additively, so Weapons and Laser both
  # feed the attack multiplier without either needing to know about the other.
  def technology_bonus(effect)
    Technology.with_effect(effect).sum do |definition|
      definition.bonus_per_level * technology_level(definition.key)
    end
  end

  def attack_multiplier = 1 + technology_bonus(:weapons)

  # Fraction of a fleet that survives a failed attack instead of being destroyed.
  def armor_survival = [ technology_bonus(:armor), 0.9 ].min

  def reload(...)
    @research = nil
    super
  end

  # Storage comes from the planet's silos. A faction banks against its own capacity
  # instead, since its worlds are industry rather than a single seat of government. An
  # empire with neither falls back to the base capacity, so uncapped income is never
  # possible.
  def storage_capacity(resource)
    return npc_faction.capacity if run_by_npc? && npc_faction

    planet&.economy&.storage_capacity(resource) || Structure::BASE_STORAGE
  end

  def storage_full?(resource)
    public_send(resource) >= storage_capacity(resource)
  end

  # Ceiling for shipments and loot, above the ceiling their own mining respects.
  def overflow_capacity(resource)
    planet&.economy&.overflow_capacity(resource) ||
      (Structure::BASE_STORAGE * PlanetEconomy::OVERFLOW_MULTIPLIER).round
  end

  # A faction has no role, so it takes no bonus — its advantages are tempo and scale.
  def resource_bonus(resource)
    case [ role, resource ]
    when [ "cultivator", :crystal ] then 1.5
    when [ "foundry", :metal ] then 1.5
    when [ "warden", :energy ] then 1.5
    else 1.0
    end
  end
end
