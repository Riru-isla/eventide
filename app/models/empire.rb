class Empire < ApplicationRecord
  ROLES = %w[cultivator foundry warden].freeze

  belongs_to :player
  belongs_to :galaxy
  belongs_to :home_sector, class_name: "Sector", optional: true
  has_many :sectors, dependent: :nullify
  has_many :fleets, dependent: :destroy
  has_one :planet, dependent: :destroy

  validates :role, inclusion: { in: ROLES }
  validates :metal, :crystal, :energy, numericality: { greater_than_or_equal_to: 0 }

  def name
    "#{player.name}'s Empire"
  end

  # Storage comes from the planet's silos. An empire without a planet falls back to the
  # base capacity so uncapped income is never possible.
  def storage_capacity(resource)
    planet&.economy&.storage_capacity(resource) || Structure::BASE_STORAGE
  end

  def storage_full?(resource)
    public_send(resource) >= storage_capacity(resource)
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
