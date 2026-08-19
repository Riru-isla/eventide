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

  # Roused means the faction is *doing* something. `dormant` knows players exist but is
  # not looking for them, so it belongs with `unaware` rather than with the states that
  # spend resources and send fleets.
  ROUSED = %w[aware hunting total_war].freeze

  # Ticks a faction takes to stir on its own once it has a reason to — a neighbour falling,
  # or being the frontier at the start of a run. Longer the deeper it sits, shorter the
  # more alert it is: an alert rim faction is up in a few hours, an oblivious core faction
  # in days.
  WAKE_DELAY = 1_200

  scope :by_power, -> { order(:power_level) }
  scope :standing, -> { where(fallen_at_tick: nil) }
  scope :fallen, -> { where.not(fallen_at_tick: nil) }
  scope :roused, -> { where(aggression: ROUSED) }
  scope :slumbering, -> { where.not(aggression: ROUSED) }

  def fallen? = fallen_at_tick.present?

  def roused? = ROUSED.include?(aggression)

  def wake_delay
    (WAKE_DELAY * power_level * (1.5 - (awareness / 100.0))).round
  end

  # The factions holding the sectors that touch this one. Waking spreads across this graph
  # and nowhere else, so escalation can never get ahead of where players have pushed.
  def neighbours
    return self.class.none if sector.nil?

    self.class.where(sector_id: sector.neighbours.select(:id)).where.not(id: id)
  end

  # A faction dies when its capital is taken, not when every system it holds is
  # cleared — so each sector ends in one battle worth organising for rather than a
  # mop-up nobody wants to do.
  def capital_held? = capital_system&.npc_faction_id == id
end
