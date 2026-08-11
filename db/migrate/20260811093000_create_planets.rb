class CreatePlanets < ActiveRecord::Migration[8.1]
  def change
    create_table :planets do |t|
      t.references :empire, null: false, foreign_key: true
      # One planet per sector; one planet per empire is enforced in the model so the
      # limit can be lifted later without a migration.
      t.references :sector, null: false, foreign_key: true, index: { unique: true }
      t.string :name, null: false

      t.timestamps
    end

    create_table :planet_structures do |t|
      t.references :planet, null: false, foreign_key: true
      t.string :kind, null: false
      t.integer :level, null: false, default: 0

      t.timestamps
    end

    add_index :planet_structures, [ :planet_id, :kind ], unique: true
  end
end
