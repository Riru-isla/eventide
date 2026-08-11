class Galaxy < ApplicationRecord
  has_many :sectors, dependent: :destroy
  has_many :players, dependent: :destroy
  has_many :empires, dependent: :destroy
  has_many :npc_factions, dependent: :destroy
  has_many :fleets, dependent: :destroy

  validates :name, presence: true
  validates :width, :height, numericality: { greater_than: 0 }

  enum :status, { active: "active", paused: "paused", completed: "completed" }, default: :active

  def center
    { x: width / 2, y: height / 2 }
  end
end
