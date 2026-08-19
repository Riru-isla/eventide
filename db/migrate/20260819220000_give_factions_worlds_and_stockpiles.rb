# Factions get real infrastructure, for the same reason they will get real fleets: if a
# shipyard is what lets a commander build a ship, a faction conjuring one from a stockpile
# is not playing by the same rules.
class GiveFactionsWorldsAndStockpiles < ActiveRecord::Migration[8.1]
  def change
    # A planet now belongs to an empire *or* a faction. Deliberately one change rather than
    # two shapes: fleets need the same treatment when raids arrive.
    change_column_null :planets, :empire_id, true
    add_reference :planets, :npc_faction, foreign_key: true

    change_table :npc_factions, bulk: true do |t|
      # Spent on defences, structures and ships once roused. A faction starts with a war
      # chest sized to its power level and touches none of it while asleep.
      t.integer :metal, null: false, default: 0
      t.integer :crystal, null: false, default: 0
    end
  end
end
