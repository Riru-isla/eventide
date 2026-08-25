# What a roused faction spends its war chest on. Projects take ticks and cost resources,
# the same as anything a commander builds — the faction's advantage is how fast it works,
# never an exemption from working.
class AddFactionProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :faction_projects do |t|
      t.references :npc_faction, null: false, foreign_key: true
      t.references :system, null: false, foreign_key: true
      t.string :kind, null: false, default: "fortify"
      t.integer :defence_gain, null: false, default: 0
      t.integer :started_at_tick, null: false
      t.integer :completes_at_tick, null: false
      t.timestamps

      t.index :completes_at_tick
    end

    # What an ordinary garrison of this faction was built to. Stored so the ceiling on
    # fortification is a property of the faction rather than a reach back into the
    # generator's tables.
    add_column :npc_factions, :base_defence, :integer, null: false, default: 0
  end
end
