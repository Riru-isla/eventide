class PlanetStructure < ApplicationRecord
  belongs_to :planet

  validates :kind, inclusion: { in: Structure::KEYS }, uniqueness: { scope: :planet_id }
  validates :level, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :built, -> { where("level > 0") }

  delegate :name, :category, :summary, :effect, to: :definition

  def definition
    Structure.find!(kind)
  end

  def built? = level.positive?

  def energy_draw = definition.energy_draw(level)

  def energy_output = definition.energy_output(level)

  def upgrade_cost = definition.upgrade_cost(level)
end
