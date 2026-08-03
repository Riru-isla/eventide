class CreateSectors < ActiveRecord::Migration[8.1]
  def change
    create_table :sectors do |t|
      t.references :galaxy, null: false, foreign_key: true
      t.integer :x
      t.integer :y
      t.string :kind
      t.references :empire, foreign_key: true
      t.references :npc_faction, foreign_key: true
      t.string :name
      t.integer :metal_rate
      t.integer :crystal_rate
      t.integer :energy_rate
      t.integer :defense_strength

      t.timestamps
    end
  end
end
