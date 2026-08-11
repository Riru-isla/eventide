class Player < ApplicationRecord
  belongs_to :user
  belongs_to :galaxy
  has_many :empires, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :galaxy_id }

  # One commander per account per galaxy, which keeps each user to a single empire
  # (and so a single planet) for now.
  validates :user_id, uniqueness: { scope: :galaxy_id, message: "already commands an empire in this galaxy" }
end
