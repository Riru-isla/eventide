class ShipType < ApplicationRecord
  ROLES = %w[cultivator foundry warden].freeze

  validates :name, presence: true, uniqueness: true
  validates :role, inclusion: { in: ROLES }, allow_nil: true
  validates :metal_cost, :crystal_cost, :energy_cost, :attack, :defense, :speed,
            numericality: { greater_than_or_equal_to: 0 }
end
