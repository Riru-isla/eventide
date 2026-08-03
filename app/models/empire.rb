class Empire < ApplicationRecord
  ROLES = %w[cultivator foundry warden].freeze

  belongs_to :player
  belongs_to :galaxy
  belongs_to :home_sector, class_name: "Sector", optional: true
  has_many :sectors, dependent: :nullify
  has_many :fleets, dependent: :destroy

  validates :role, inclusion: { in: ROLES }
  validates :metal, :crystal, :energy, numericality: { greater_than_or_equal_to: 0 }

  def name
    "#{player.name}'s Empire"
  end

  def resource_bonus(resource)
    case [ role, resource ]
    when [ "cultivator", :crystal ] then 1.5
    when [ "foundry", :metal ] then 1.5
    when [ "warden", :energy ] then 1.5
    else 1.0
    end
  end
end
