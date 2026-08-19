class NpcFaction < ApplicationRecord
  # How a faction regards the players. Waking is driven by what happens next door, not by
  # a numbered ladder: a faction has no reason to stir until a neighbouring sector falls
  # or a player turns up in its space.
  #
  # Nothing reads these yet; faction behaviour is a later step. They exist now so
  # generation and the fall of a capital can set them.
  AGGRESSIONS = {
    unaware: "unaware",       # does not know players exist
    dormant: "dormant",       # aware, but only strikes back when struck
    aware: "aware",           # patrols and raids what it finds
    hunting: "hunting",       # actively scouts for players and masses fleets
    total_war: "total_war"    # the last faction standing, throwing everything at them
  }.freeze

  belongs_to :galaxy
  belongs_to :sector, optional: true
  belongs_to :capital_system, class_name: "System", optional: true
  has_many :systems, dependent: :nullify

  enum :aggression, AGGRESSIONS, default: :unaware

  validates :name, presence: true
  validates :strength_level, numericality: { greater_than_or_equal_to: 0 }
  validates :power_level, numericality: { only_integer: true, greater_than: 0 }

  scope :by_power, -> { order(:power_level) }
  scope :standing, -> { where(fallen_at_tick: nil) }
  scope :fallen, -> { where.not(fallen_at_tick: nil) }
  scope :awake, -> { where.not(aggression: "unaware") }
  scope :asleep, -> { where(aggression: "unaware") }

  def fallen? = fallen_at_tick.present?

  # A faction dies when its capital is taken, not when every system it holds is
  # cleared — so each sector ends in one battle worth organising for rather than a
  # mop-up nobody wants to do.
  def capital_held? = capital_system&.npc_faction_id == id
end
