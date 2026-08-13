class AddGalaxySizesAndFactionTiers < ActiveRecord::Migration[8.1]
  def change
    # Dimensions come from the size chosen when a session is created, rather than being
    # passed in ad hoc.
    add_column :galaxies, :size, :string, null: false, default: "small"

    change_table :npc_factions, bulk: true do |t|
      # 1 is the outermost and weakest band, 5 the core. Replaces the old
      # strength-ordered list, whose band mapping was inverted.
      t.integer :tier, null: false, default: 1
      # How the faction behaves toward players. Only the outermost tier is awake at the
      # start; the rest do not know players exist until the tier outside them falls.
      t.string :aggression, null: false, default: "unaware"
      # Taking this sector ends the faction, rather than clearing every sector it holds.
      t.references :capital_sector, foreign_key: { to_table: :sectors }
      # Set when the capital falls. Nil means still standing; the tick is kept so the
      # galaxy has a record of when each escalation happened.
      t.integer :fallen_at_tick
    end

    add_index :npc_factions, [ :galaxy_id, :tier ]
  end
end
