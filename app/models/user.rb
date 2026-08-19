class User < ApplicationRecord
  # Players log in with a username; there is no email column. :validatable is
  # left out for that reason, so password rules are declared explicitly below.
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable

  has_many :players, dependent: :destroy
  has_many :empires, through: :players

  # Whoever sets the game up registers first, and somebody has to be able to create the
  # first galaxy. There is no other bootstrap path on a laptop-hosted server.
  before_create :promote_first_account

  validates :username, presence: true, uniqueness: true
  validates :password, length: { minimum: 6 }, if: -> { password.present? }
  validates :password, confirmation: true, if: -> { password.present? }

  private

  def promote_first_account
    self.admin = true if User.none?
  end
end
