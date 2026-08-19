# One row per touching pair, stored both ways round so a sector's neighbours are a single
# query. Written once at generation; sector boundaries never move.
class SectorBorder < ApplicationRecord
  belongs_to :sector
  belongs_to :neighbour, class_name: "Sector"

  validates :sector_id, uniqueness: { scope: :neighbour_id }
end
