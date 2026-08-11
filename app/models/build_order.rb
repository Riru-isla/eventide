# One queued construction job on a planet.
#
# Only the order at the front of the queue is building: it has a `completes_at_tick`.
# The rest wait with that field nil until their turn comes round, so a queued order's
# finish time is not promised before it can be known.
#
# Times are counted in ticks. When game time moves to wall-clock timestamps this is
# the field that changes.
class BuildOrder < ApplicationRecord
  belongs_to :planet

  validates :kind, inclusion: { in: Structure::KEYS }
  validates :target_level, numericality: { only_integer: true, greater_than: 0 }
  validates :ticks_required, numericality: { only_integer: true, greater_than: 0 }

  scope :queued, -> { order(:position, :id) }
  scope :building, -> { where.not(completes_at_tick: nil) }
  scope :waiting, -> { where(completes_at_tick: nil) }
  scope :due, ->(tick) { building.where(completes_at_tick: ..tick) }

  delegate :name, to: :definition

  def definition
    Structure.find!(kind)
  end

  def building? = completes_at_tick.present?

  def ticks_remaining(current_tick)
    return ticks_required unless building?

    [ completes_at_tick - current_tick, 0 ].max
  end

  def progress(current_tick)
    return 0.0 unless building?

    elapsed = ticks_required - ticks_remaining(current_tick)
    (elapsed.to_f / ticks_required * 100).clamp(0, 100)
  end

  # Marks this order as under way, finishing `ticks_required` from now.
  def start!(current_tick)
    update!(started_at_tick: current_tick, completes_at_tick: current_tick + ticks_required)
  end
end
