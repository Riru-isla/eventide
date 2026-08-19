# Which sectors touch which is now load-bearing rather than incidental: a faction has no
# reason to stir until something happens *next door*, so waking is driven by the border
# graph. Computed once at generation from the ownership grid it already builds, because
# rederiving it from geometry every tick would be wasteful.
class AddSectorBordersAndWakeClocks < ActiveRecord::Migration[8.1]
  def change
    create_table :sector_borders do |t|
      t.references :sector, null: false, foreign_key: true
      t.references :neighbour, null: false, foreign_key: { to_table: :sectors }
      # Stored both ways round, so "who borders me" is one query rather than a union.
      t.index [ :sector_id, :neighbour_id ], unique: true
    end

    # When this faction stirs on its own. Null until a neighbour falls — nothing beyond the
    # front has a clock running at all, which is what stops escalation outpacing players.
    add_column :npc_factions, :wake_at_tick, :integer
    add_index :npc_factions, :wake_at_tick
  end
end
