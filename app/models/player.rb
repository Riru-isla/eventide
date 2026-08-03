class Player < ApplicationRecord
  has_many :empires, dependent: :destroy

  validates :name, presence: true, uniqueness: true
end
