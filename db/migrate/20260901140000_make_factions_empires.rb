# Players and factions become the same kind of thing: an Empire that holds systems, runs
# planets, banks resources and sends fleets. `empire_type` says who is driving.
#
# The point is not tidiness. It is that the AI and a commander now travel identical code
# paths — PlanetEconomy, BuildQueue, Shipyard, combat — so balance cannot quietly diverge
# between them, and nothing has to be kept in step by hand.
#
# NpcFaction survives as the AI's *brain* rather than as an owner: aggression, awareness,
# power level, its capital and its wake clock. Keeping it apart avoids an empires table
# where a dozen columns are permanently null for every human player.
class MakeFactionsEmpires < ActiveRecord::Migration[8.1]
  def change
    change_table :empires, bulk: true do |t|
      t.string :empire_type, null: false, default: "player"
      # Names and colours belong to the actor now, whoever drives it, so the map and every
      # roster can read one place instead of asking which kind it is holding.
      t.string :name
      t.string :color
    end

    # An NPC empire has no account behind it.
    change_column_null :empires, :player_id, true

    add_reference :npc_factions, :empire, foreign_key: true

    # Resources move to the empire, where a commander's already live.
    remove_column :npc_factions, :metal, :integer, null: false, default: 0
    remove_column :npc_factions, :crystal, :integer, null: false, default: 0
    remove_column :npc_factions, :name, :string
    remove_column :npc_factions, :color, :string

    # One owner column apiece. This is the whole point: no more clearing one side and
    # setting the other every time something changes hands.
    remove_reference :systems, :npc_faction, foreign_key: true, index: true
    remove_reference :planets, :npc_faction, foreign_key: true, index: true
  end
end
