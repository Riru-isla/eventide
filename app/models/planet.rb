class Planet < ApplicationRecord
  belongs_to :empire
  belongs_to :sector
  has_many :structures, class_name: "PlanetStructure", dependent: :destroy
  has_many :build_orders, dependent: :destroy

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

  def queue
    @queue ||= BuildQueue.new(self)
  end

  # Both helpers cache the planet's state, including the galaxy's current tick, so
  # they have to go when the record is reloaded or they answer with stale numbers.
  def reload(...)
    @economy = nil
    @queue = nil
    super
  end
end
