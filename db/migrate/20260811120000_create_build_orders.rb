class CreateBuildOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :build_orders do |t|
      t.references :planet, null: false, foreign_key: true
      t.string :kind, null: false
      t.integer :target_level, null: false
      t.integer :ticks_required, null: false
      # Set only once an order reaches the front of the queue and starts building.
      t.integer :started_at_tick
      t.integer :completes_at_tick
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :build_orders, [ :planet_id, :position ]
    add_index :build_orders, :completes_at_tick
  end
end
