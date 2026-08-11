class Player < ApplicationRecord
  belongs_to :user
  belongs_to :galaxy
  has_many :empires, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :galaxy_id }
end
