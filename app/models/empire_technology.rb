class EmpireTechnology < ApplicationRecord
  belongs_to :empire

  validates :kind, inclusion: { in: Technology::KEYS }, uniqueness: { scope: :empire_id }
  validates :level, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :researched, -> { where("level > 0") }

  delegate :name, :category, :summary, to: :definition

  def definition
    Technology.find!(kind)
  end

  def researched? = level.positive?
end
