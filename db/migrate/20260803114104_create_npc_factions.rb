class CreateNpcFactions < ActiveRecord::Migration[8.1]
  def change
    create_table :npc_factions do |t|
      t.references :galaxy, null: false, foreign_key: true
      t.string :name
      t.string :color
      t.integer :strength_level
      t.integer :tech_level

      t.timestamps
    end
  end
end
