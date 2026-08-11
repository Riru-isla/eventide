class Planet < ApplicationRecord
  belongs_to :empire
  belongs_to :sector
  has_many :structures, class_name: "PlanetStructure", dependent: :destroy

  validates :name, presence: true

  # One planet per empire for now. Lifting this is deliberately a one-line change:
  # nothing else in the model assumes a single planet.
  validates :empire_id, uniqueness: { message: "already has a planet" }

  def structure(key)
    structures.detect { |record| record.kind == key }
  end

  def level_of(key)
    structure(key)&.level.to_i
  end

  def economy
    @economy ||= PlanetEconomy.new(self)
  end
end
