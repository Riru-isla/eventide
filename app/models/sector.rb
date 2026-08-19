# A large region of the galaxy: a few dozen to a few hundred systems, grown from a single
# seed point so it comes out as an irregular contiguous territory.
#
# Sectors are what the campaign is made of. One holds the core, one holds every player,
# and each of the rest is one NPC faction's homeland — so taking a faction means pushing
# into its sector and crossing it, rather than chasing a lone system around a ring.
class Sector < ApplicationRecord
  KINDS = %w[standard core spawn].freeze

  belongs_to :galaxy
  has_many :systems, dependent: :nullify
  has_one :npc_faction, dependent: :nullify

  validates :name, presence: true
  validates :seed_x, :seed_y, numericality: { only_integer: true }
  validates :weight, numericality: { greater_than: 0 }
  validates :kind, inclusion: { in: KINDS }
  validates :power_level, numericality: { only_integer: true, greater_than: 0 }

  scope :by_power, -> { order(:power_level) }
  scope :holdable, -> { where.not(kind: "spawn") }

  def core? = kind == "core"
  def spawn? = kind == "spawn"

  # The seed is always the deepest point of its own region — nothing else can be nearer
  # to it — which is why the core can simply be placed on one and be guaranteed to sit
  # inside the sector rather than on its edge.
  def seed_system
    systems.find_by(x: seed_x, y: seed_y)
  end

  def distance_to_core
    Math.sqrt(((seed_x - galaxy.core_x)**2) + ((seed_y - galaxy.core_y)**2))
  end
end
