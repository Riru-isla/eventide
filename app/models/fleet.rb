class Fleet < ApplicationRecord
  STATUSES = %w[orbiting moving returning].freeze

  belongs_to :empire
  belongs_to :galaxy
  belongs_to :origin_sector, class_name: "Sector"
  belongs_to :target_sector, class_name: "Sector", optional: true

  scope :moving, -> { where(status: "moving") }

  validates :status, inclusion: { in: STATUSES }
  validates :ships, presence: true

  def total_ships
    ships.values.sum
  end

  def power
    ships.sum do |ship_type_name, count|
      ship_type = ShipType.find_by(name: ship_type_name)
      ship_type ? ship_type.attack * count : 0
    end
  end
end
