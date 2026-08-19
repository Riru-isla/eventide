# A galaxy without a core is not a galaxy: every system's depth, every sector's power
# level and the whole campaign are measured from it. One built before the rebuild had no
# core, and the planet screen died on `nil can't be coerced into Integer` rather than
# failing anywhere near the cause.
class RequireACoreOnEveryGalaxy < ActiveRecord::Migration[8.1]
  def change
    change_column_null :galaxies, :core_x, false
    change_column_null :galaxies, :core_y, false
  end
end
