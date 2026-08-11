class CreateTechnologies < ActiveRecord::Migration[8.1]
  def change
    # Research is empire-wide, unlike structures which belong to a planet.
    create_table :empire_technologies do |t|
      t.references :empire, null: false, foreign_key: true
      t.string :kind, null: false
      t.integer :level, null: false, default: 0

      t.timestamps
    end

    add_index :empire_technologies, [ :empire_id, :kind ], unique: true

    create_table :research_orders do |t|
      t.references :empire, null: false, foreign_key: true
      t.string :kind, null: false
      t.integer :target_level, null: false
      t.integer :ticks_required, null: false
      t.integer :started_at_tick
      t.integer :completes_at_tick

      t.timestamps
    end

    add_index :research_orders, :completes_at_tick
  end
end
