class Sector < ApplicationRecord
  KINDS = %w[empty home resource outpost fortress core].freeze

  belongs_to :galaxy
  belongs_to :empire, optional: true
  belongs_to :npc_faction, optional: true
  has_many :stationed_fleets, class_name: "Fleet", foreign_key: "origin_sector_id", dependent: :nullify
  has_one :planet, dependent: :destroy

  validates :x, :y, presence: true, numericality: { only_integer: true }
  validates :kind, inclusion: { in: KINDS }
  validates :x, uniqueness: { scope: [ :galaxy_id, :y ] }

  scope :at, ->(x, y) { where(x: x, y: y) }
  scope :owned_by, ->(empire) { where(empire: empire) }
  scope :npc, -> { where.not(npc_faction_id: nil) }

  def coordinate
    "#{x},#{y}"
  end

  def distance_to(other_x, other_y)
    Math.sqrt((x - other_x) ** 2 + (y - other_y) ** 2)
  end

  def distance_to_center
    center = galaxy.center
    distance_to(center[:x], center[:y])
  end

  # Defence a fleet actually has to beat: the sector's own strength plus whatever the
  # planet standing on it has built.
  def total_defence
    defense_strength.to_i + (planet&.economy&.defence_rating).to_i
  end

  def owner_name
    return empire.player.name if empire
    return npc_faction.name if npc_faction
    "Unclaimed"
  end
end
