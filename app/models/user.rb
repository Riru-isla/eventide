class User < ApplicationRecord
  # Players log in with a username; there is no email column. :validatable is
  # left out for that reason, so password rules are declared explicitly below.
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable

  has_many :players, dependent: :destroy

  validates :username, presence: true, uniqueness: true
  validates :password, length: { minimum: 6 }, if: -> { password.present? }
  validates :password, confirmation: true, if: -> { password.present? }
end
