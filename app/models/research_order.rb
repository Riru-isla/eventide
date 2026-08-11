# An empire researches one technology at a time, so unlike BuildOrder there is no
# queue position — there is at most one order, and it is always under way.
class ResearchOrder < ApplicationRecord
  belongs_to :empire

  validates :kind, inclusion: { in: Technology::KEYS }
  validates :target_level, numericality: { only_integer: true, greater_than: 0 }
  validates :ticks_required, numericality: { only_integer: true, greater_than: 0 }

  scope :due, ->(tick) { where(completes_at_tick: ..tick) }

  delegate :name, to: :definition

  def definition
    Technology.find!(kind)
  end

  def ticks_remaining(current_tick)
    [ completes_at_tick - current_tick, 0 ].max
  end

  def progress(current_tick)
    elapsed = ticks_required - ticks_remaining(current_tick)

    (elapsed.to_f / ticks_required * 100).clamp(0, 100)
  end
end
