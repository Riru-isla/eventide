class CreateEmpires < ActiveRecord::Migration[8.1]
  def change
    create_table :empires do |t|
      t.references :player, null: false, foreign_key: true
      t.references :galaxy, null: false, foreign_key: true
      t.string :role
      t.integer :home_sector
      t.integer :metal
      t.integer :crystal
      t.integer :energy

      t.timestamps
    end
  end
end
