class CreateFleets < ActiveRecord::Migration[8.1]
  def change
    create_table :fleets do |t|
      t.references :empire, null: false, foreign_key: true
      t.references :galaxy, null: false, foreign_key: true
      t.integer :origin_sector
      t.integer :target_sector
      t.integer :arrival_tick
      t.string :status
      t.json :ships

      t.timestamps
    end
  end
end
