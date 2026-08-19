class Empire < ApplicationRecord
  ROLES = %w[cultivator foundry warden].freeze

  belongs_to :player
  belongs_to :galaxy
  belongs_to :home_system, class_name: "System", optional: true
  has_many :systems, dependent: :nullify
  has_many :fleets, dependent: :destroy
  has_one :planet, dependent: :destroy
  has_many :technologies, class_name: "EmpireTechnology", dependent: :destroy
  # An empire researches one project at a time; research_orders is the plural side used
  # for querying due work, research_order the single project under way.
  has_many :research_orders, dependent: :destroy
  has_one :research_order, dependent: :destroy

  validates :role, inclusion: { in: ROLES }
  validates :metal, :crystal, :energy, numericality: { greater_than_or_equal_to: 0 }

  def name
    "#{player.name}'s Empire"
  end

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

  # Storage comes from the planet's silos. An empire without a planet falls back to the
  # base capacity so uncapped income is never possible.
  def storage_capacity(resource)
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

  def resource_bonus(resource)
    case [ role, resource ]
    when [ "cultivator", :crystal ] then 1.5
    when [ "foundry", :metal ] then 1.5
    when [ "warden", :energy ] then 1.5
    else 1.0
    end
  end
end
