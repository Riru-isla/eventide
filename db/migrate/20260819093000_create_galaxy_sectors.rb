# Sectors are the large regions the galaxy is carved into — a few dozen to a few hundred
# systems each, grown from a seed point so they come out as irregular contiguous
# territories rather than rings. One holds the core, one holds every player, and each of
# the rest is one faction's homeland.
class CreateGalaxySectors < ActiveRecord::Migration[8.1]
  def change
    create_table :sectors do |t|
      t.references :galaxy, null: false, foreign_key: true
      t.string :name, null: false
      # The point the region was grown from. A seed always lies inside its own region and
      # is its deepest point, which is why the core can simply be placed on one.
      t.integer :seed_x, null: false
      t.integer :seed_y, null: false
      # Region size. A heavier seed claims systems further away, so weight is the dial
      # that makes the core sector big and the rim sectors small.
      t.float :weight, null: false, default: 1.0
      t.string :kind, null: false, default: "standard"
      # 1 is furthest from the core. Derived from the seed's distance to it, so it
      # measures depth rather than declaring an order.
      t.integer :power_level, null: false, default: 1
      t.timestamps
    end

    add_reference :systems, :sector, foreign_key: true, index: true
    add_reference :npc_factions, :sector, foreign_key: true, index: true

    # `tier` implied a ladder to be climbed in order. Waking is driven by which sectors
    # border a fallen one, not by a number, so this only ever measured strength.
    rename_column :npc_factions, :tier, :power_level

    # Where the campaign is pushing toward. Stored rather than looked up because every
    # system's depth is measured from it, on every generation and every render.
    add_column :galaxies, :core_x, :integer
    add_column :galaxies, :core_y, :integer
  end
end
