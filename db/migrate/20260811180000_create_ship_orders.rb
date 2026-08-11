class CreateShipOrders < ActiveRecord::Migration[8.1]
  # Ships built earlier were stored in Fleet#ships under their display name. They are
  # now keyed by a stable catalogue key so a ship can be renamed without orphaning
  # every fleet that holds one.
  RENAMES = {
    "Fighter" => "light_fighter",
    "Cruiser" => "medium_fighter",
    "Harvester" => "transport",
    "Carrier" => "heavy_fighter",
    "Dreadnought" => "battle_cruiser"
  }.freeze

  def up
    create_table :ship_orders do |t|
      t.references :planet, null: false, foreign_key: true
      t.string :kind, null: false
      t.integer :quantity, null: false
      t.integer :ticks_required, null: false
      t.integer :started_at_tick
      t.integer :completes_at_tick
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :ship_orders, [ :planet_id, :position ]
    add_index :ship_orders, :completes_at_tick

    rekey_fleets(RENAMES)

    # Ship stats move into the Structure/Technology-style catalogue in app/models.
    drop_table :ship_types
  end

  def down
    create_table :ship_types do |t|
      t.integer :attack
      t.integer :crystal_cost
      t.integer :defense
      t.integer :energy_cost
      t.integer :metal_cost
      t.string :name
      t.string :role
      t.integer :speed
      t.timestamps
    end

    rekey_fleets(RENAMES.invert)
    drop_table :ship_orders
  end

  private

  def rekey_fleets(mapping)
    execute("SELECT id, ships FROM fleets").to_a.each do |row|
      ships = JSON.parse(row["ships"].presence || "{}")
      renamed = ships.transform_keys { |key| mapping.fetch(key, key) }
      next if renamed == ships

      execute("UPDATE fleets SET ships = #{connection.quote(renamed.to_json)} WHERE id = #{row['id'].to_i}")
    end
  end
end
