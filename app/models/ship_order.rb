# A batch of hulls queued at a planet's shipyard. Mirrors BuildOrder: only the order at
# the front is under way, and it is the one carrying a `completes_at_tick`.
class ShipOrder < ApplicationRecord
  belongs_to :planet

  validates :kind, inclusion: { in: ShipType::KEYS }
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :ticks_required, numericality: { only_integer: true, greater_than: 0 }

  scope :queued, -> { order(:position, :id) }
  scope :building, -> { where.not(completes_at_tick: nil) }
  scope :waiting, -> { where(completes_at_tick: nil) }
  scope :due, ->(tick) { building.where(completes_at_tick: ..tick) }

  delegate :name, to: :definition

  def definition
    ShipType.find!(kind)
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

  def start!(current_tick)
    update!(started_at_tick: current_tick, completes_at_tick: current_tick + ticks_required)
  end
end
