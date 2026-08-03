class Player < ApplicationRecord
  has_many :empires, dependent: :destroy

  has_secure_password

  validates :name, presence: true, uniqueness: true
  validates :username, presence: true, uniqueness: true
end
