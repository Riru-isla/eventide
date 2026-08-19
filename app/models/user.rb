class User < ApplicationRecord
  # Players log in with a username; there is no email column. :validatable is
  # left out for that reason, so password rules are declared explicitly below.
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable

  has_many :players, dependent: :destroy
  has_many :empires, through: :players

  # Administrators run the server rather than play it, and are granted from the console
  # only — `bin/rails "admin:grant[username]"`. Nothing in the game promotes an account,
  # so there is no path from being a player to being an administrator.
  scope :administrators, -> { where(admin: true) }

  validates :username, presence: true, uniqueness: true
  validates :password, length: { minimum: 6 }, if: -> { password.present? }
  validates :password, confirmation: true, if: -> { password.present? }
end
