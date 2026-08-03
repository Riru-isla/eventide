class CreateShipTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :ship_types do |t|
      t.string :name
      t.string :role
      t.integer :metal_cost
      t.integer :crystal_cost
      t.integer :energy_cost
      t.integer :attack
      t.integer :defense
      t.integer :speed

      t.timestamps
    end
  end
end
