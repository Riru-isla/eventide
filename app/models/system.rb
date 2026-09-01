class System < ApplicationRecord
  KINDS = %w[empty home resource outpost fortress core].freeze

  belongs_to :galaxy
  # One owner, whoever it is. Before factions were empires this was two columns that had
  # to be kept exclusive by hand on every capture.
  belongs_to :empire, optional: true
  belongs_to :sector, optional: true
  has_many :stationed_fleets, class_name: "Fleet", foreign_key: "origin_system_id", dependent: :nullify
  has_one :planet, dependent: :destroy

  validates :x, :y, presence: true, numericality: { only_integer: true }
  validates :kind, inclusion: { in: KINDS }
  validates :x, uniqueness: { scope: [ :galaxy_id, :y ] }

  scope :at, ->(x, y) { where(x: x, y: y) }
  scope :owned_by, ->(empire) { where(empire: empire) }
  scope :held, -> { where.not(empire_id: nil) }
  # Held by a faction rather than by a commander. Before factions were empires this was
  # simply "has an npc_faction_id".
  scope :garrisoned, -> { joins(:empire).merge(Empire.artificial) }
  scope :commanded, -> { joins(:empire).merge(Empire.commanded) }

  def coordinate
    "#{x},#{y}"
  end

  def distance_to(other_x, other_y)
    Math.sqrt((x - other_x) ** 2 + (y - other_y) ** 2)
  end

  # How far this system is from what the campaign is pushing toward. Everything about
  # difficulty is measured from here: sector weight, power level, and garrison strength
  # all rise as this falls.
  def distance_to_core
    distance_to(galaxy.core_x, galaxy.core_y)
  end

  # Defence a fleet actually has to beat: the system's own strength plus whatever the
  # planet standing on it has built.
  def total_defence
    defense_strength.to_i + (planet&.economy&.defence_rating).to_i
  end

  def owner_name
    return "Unclaimed" if empire.nil?

    empire.run_by_npc? ? empire.name : empire.player.name
  end
end
