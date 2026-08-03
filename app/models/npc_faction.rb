class NpcFaction < ApplicationRecord
  belongs_to :galaxy
  has_many :sectors, dependent: :nullify

  validates :name, presence: true
  validates :strength_level, numericality: { greater_than_or_equal_to: 0 }
end
