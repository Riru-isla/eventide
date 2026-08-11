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

  def base_power
    ships.sum do |ship_type_name, count|
      ship_type = ShipType.find_by(name: ship_type_name)
      ship_type ? ship_type.attack * count : 0
    end
  end

  # Weapons and Laser Technology both feed the empire's attack multiplier.
  def power
    (base_power * empire.attack_multiplier).round
  end

  # Applies Armor Technology to a failed attack: some of the fleet limps home instead
  # of the whole force being lost. Returns false when nothing survived.
  def retreat!
    survivors = ships.transform_values { |count| (count * empire.armor_survival).floor }
                     .reject { |_, count| count.zero? }

    return false if survivors.empty?

    update!(ships: survivors, target_sector: nil, status: "orbiting", arrival_tick: nil)
    true
  end
end
