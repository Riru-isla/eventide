class CreateGalaxies < ActiveRecord::Migration[8.1]
  def change
    create_table :galaxies do |t|
      t.string :name
      t.integer :width
      t.integer :height
      t.integer :current_tick
      t.string :status

      t.timestamps
    end
  end
end
