# One thing a faction is currently building. Costs are paid up front and the result lands
# when the tick arrives, exactly as a commander's build order does.
class FactionProject < ApplicationRecord
  KINDS = %w[fortify].freeze

  belongs_to :npc_faction
  belongs_to :system

  validates :kind, inclusion: { in: KINDS }
  validates :defence_gain, numericality: { greater_than: 0 }
  validates :completes_at_tick, numericality: { greater_than_or_equal_to: :started_at_tick }

  scope :due_by, ->(tick) { where(completes_at_tick: ..tick) }

  def ticks_remaining(current_tick)
    [ completes_at_tick - current_tick, 0 ].max
  end
end
